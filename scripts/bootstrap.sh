#!/bin/bash
# ==============================================================================
# scripts/bootstrap_backend.sh
# Purpose: Provision a zero-cost Azure backend for Terraform state and automate
#          RBAC (Role-Based Access Control) permissions.
#
# SRE & Architecture Context:
# 1. State Separation: Decouples Terraform state ("The Brain") from the ephemeral 
#    infrastructure ("The Muscle").
# 2. RBAC Security: Replaces access keys with Microsoft Entra ID (Azure AD) 
#    authentication. Assigns strict 'Storage Blob Data Contributor' roles.
# 3. Automation: Fixes the 'Bootstrap Problem' by pre-authorizing the CI/CD 
#    Service Principal and the local engineer before pipeline execution.
# 4. FinOps: Deploys Standard_LRS (Locally Redundant Storage) to minimize costs.
# ==============================================================================

# SRE Practice: Fail-fast. Abort script immediately if any command fails.
set -e

# 1. Configuration Variables
RESOURCE_GROUP="rg-secureops-tfstate"
LOCATION="eastus"

# Storage Account names must be globally unique across Azure. Appending $RANDOM ensures this.
STORAGE_ACCOUNT_NAME="stsecureops${UNIQUE_SUFFIX}"CONTAINER_NAME="tfstate"

# Pipeline Service Principal App ID (Client ID)
SP_APP_ID="d1f048bc-4d8a-43d1-94c0-44212655533b"

echo "=== SECUREOPS PIPELINE: INFRASTRUCTURE & IAM BOOTSTRAP ==="

# ------------------------------------------------------------------------------
# STEP 0: Session Verification
# Ensure the local environment is authenticated against Azure CLI.
# ------------------------------------------------------------------------------
echo "[0/5] Verifying Azure CLI session..."
az account show -o none || az login

# ------------------------------------------------------------------------------
# STEP 1: Create State Resource Group (The Vault)
# ------------------------------------------------------------------------------
echo ""
echo "[1/5] Creating Resource Group: $RESOURCE_GROUP..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" -o table

# ------------------------------------------------------------------------------
# STEP 2: Create Storage Account
# ------------------------------------------------------------------------------
echo ""
echo "[2/5] Creating Storage Account: $STORAGE_ACCOUNT_NAME (Standard_LRS)..."
az storage account create \
  --name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --encryption-services blob \
  -o table

# ------------------------------------------------------------------------------
# STEP 3: Create Blob Container
# ------------------------------------------------------------------------------
echo ""
echo "[3/5] Creating Storage Container: $CONTAINER_NAME..."
az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --auth-mode login \
  -o table

# ------------------------------------------------------------------------------
# STEP 4: RBAC Role Assignments (Storage Blob Data Contributor)
# Secures the state file by explicitly granting Data Plane access.
# ------------------------------------------------------------------------------
echo ""
echo "[4/5] Configuring RBAC Role Assignments..."
SA_ID=$(az storage account show --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv)
USER_ID=$(az ad signed-in-user show --query id -o tsv)

echo "  -> Assigning role to local user ($USER_ID)..."
az role assignment create \
    --assignee "$USER_ID" \
    --role "Storage Blob Data Contributor" \
    --scope "$SA_ID" \
    -o none

# SRE Fix: Ensure SP exists in local tenant, then retrieve its Object ID
az ad sp create --id "$SP_APP_ID" >/dev/null 2>&1 || true
SP_OBJ_ID=$(az ad sp show --id "$SP_APP_ID" --query id -o tsv)

echo "  -> Assigning role to Pipeline Service Principal ($SP_OBJ_ID)..."
az role assignment create \
    --assignee-object-id "$SP_OBJ_ID" \
    --assignee-principal-type "ServicePrincipal" \
    --role "Storage Blob Data Contributor" \
    --scope "$SA_ID" \
    -o none

# ------------------------------------------------------------------------------
# STEP 5: Azure AD Propagation Cooldown
# Mitigates AuthorizationPermissionMismatch (403) errors by allowing Azure 
# time to replicate IAM permissions across its global control plane.
# ------------------------------------------------------------------------------
echo ""
echo "[5/5] Azure AD Propagation Cooldown..."
echo "Waiting 60 seconds for RBAC propagation..."
sleep 60

echo ""
echo "=================================================================="
echo "SETUP COMPLETE: TERRAFORM BACKEND PROVISIONED & SECURED"
echo "=================================================================="
echo "ACTION REQUIRED for Azure DevOps Pipeline:"
echo "Update the pipeline variables with the following details:"
echo ""
echo "  Name:  STORAGE_ACCOUNT_NAME"
echo "  Value: $STORAGE_ACCOUNT_NAME"
echo "=================================================================="