#!/bin/bash
# ==============================================================================
# scripts/bootstrap.sh
# Purpose: Provision a zero-cost Azure backend for Terraform state.
#
# SRE & Architecture Context:

# 1. State Separation: We decouple the Terraform state ("The Brain") from the 
#    ephemeral infrastructure ("The Muscle"). This persistent backend allows the 
#    CI/CD pipeline to destroy compute resources without losing its memory.

# 2. OIDC Identity: Workload identity federation is managed directly via Azure 
#    DevOps Service Connections, avoiding static service principal secrets.

# 3. FinOps: We deploy Standard_LRS (Locally Redundant Storage) to minimize costs 
#    while maintaining the necessary lock/state management features.
# ==============================================================================

# SRE Practice: Fail-fast. Abort script immediately if any command fails.
set -e

# 1. Configuration Variables
RESOURCE_GROUP="rg-secureops-tfstate"
LOCATION="eastus" 
# Storage Account names must be globally unique across Azure. Appending $RANDOM ensures this.
STORAGE_ACCOUNT_NAME="stsecureops$RANDOM" 
CONTAINER_NAME="tfstate"

echo "=== SECUREOPS PIPELINE: INFRASTRUCTURE BOOTSTRAP ==="

# ------------------------------------------------------------------------------
# STEP 0: Session Verification
# Ensure the local environment is authenticated against Azure CLI.
# ------------------------------------------------------------------------------
echo "[0/3] Verifying Azure CLI session..."
az account show -o none || az login

# ------------------------------------------------------------------------------
# STEP 1: Create State Resource Group (The Vault)
# This resource group acts as the permanent vault for our state file.
# ------------------------------------------------------------------------------
echo ""
echo "[1/3] Creating Resource Group: $RESOURCE_GROUP..."
az group create --name $RESOURCE_GROUP --location $LOCATION -o table

# ------------------------------------------------------------------------------
# STEP 2: Create Storage Account
# Provisions the storage account that will host the blob container.
# ------------------------------------------------------------------------------
echo ""
echo "[2/3] Creating Storage Account: $STORAGE_ACCOUNT_NAME (Standard_LRS)..."
az storage account create \
  --name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  -o table

# ------------------------------------------------------------------------------
# STEP 3: Create Blob Container
# This container will hold the actual terraform.tfstate file.
# ------------------------------------------------------------------------------
echo ""
echo "[3/3] Creating Storage Container: $CONTAINER_NAME..."
az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT_NAME \
  --auth-mode login \
  -o table

echo ""
echo "=================================================================="
echo "SETUP COMPLETE: TERRAFORM BACKEND PROVISIONED"
echo "=================================================================="
echo "ACTION REQUIRED for Azure DevOps Pipeline:"
echo "Go to your Azure DevOps project -> Pipelines -> Edit -> Variables"
echo "Create or update the variable with the following details:"
echo ""
echo "  Name:  STORAGE_ACCOUNT_NAME"
echo "  Value: $STORAGE_ACCOUNT_NAME"
echo ""
echo "The CI/CD pipeline YAML will dynamically inject this value into"
echo "'terraform init' to maintain a secure, secretless architecture."
echo "=================================================================="