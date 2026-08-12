#!/bin/bash
# ==============================================================================
# teardown.sh
# Purpose: Local FinOps script to securely destroy ephemeral lab infrastructure
# and perform a deep clean of the Terraform state backend.
#
# SRE & FinOps Context:
# This script is designed to run locally to clean up cloud resources and prevent unexpected Azure billing.
# 
# Lessons Learned & Architecture Notes:

# 1. Fail-Fast (set -e): We enforce this so the script aborts immediately on any 
#    error. Previously, a missing local file caused Terraform to fail silently, 
#    leading the script to delete the state file while leaving the infrastructure 
#    orphaned and running in Azure.

# 2. Dummy Files: The pipeline dynamically generates an SSH key. Since this local 
#    script doesn't have that key, Terraform's file() function crashes. We create 
#    a dummy 'ephemeral_ssh_key.pub' to satisfy the state lock and safely destroy.

# 3. Dynamic Pathing: Avoids relative path errors by calculating the script's 
#    absolute origin directory instead of assuming execution from the root folder.
# ==============================================================================

# SRE Practice: Fail-fast. Abort script immediately if any command exits with a non-zero status.
set -e

echo "=== Starting Deep Clean Teardown (FinOps) ==="

# ------------------------------------------------------------------------------
# STEP 1: Session Verification
# Ensure the local environment is authenticated against Azure.
# ------------------------------------------------------------------------------
echo "[1/5] Verifying Azure CLI session..."
az account show -o none || az login

# ------------------------------------------------------------------------------
# STEP 2: Auto-detect the Terraform State 'Brain'
# Instead of hardcoding or asking for input, dynamically query Azure for the 
# Storage Account name inside the bootstrap resource group.
# ------------------------------------------------------------------------------
echo ""
echo "[2/5] Auto-detecting Terraform state Storage Account..."
STORAGE_ACCOUNT_NAME=$(az storage account list --resource-group "rg-secureops-tfstate" --query "[0].name" -o tsv)

if [ -z "$STORAGE_ACCOUNT_NAME" ]; then
    echo "Error: No Storage Account found in resource group 'rg-secureops-tfstate'."
    echo "Exiting to prevent state corruption or unintended behavior."
    exit 1
fi
echo "Found Storage Account: $STORAGE_ACCOUNT_NAME"

# ------------------------------------------------------------------------------
# STEP 3: Dynamic Pathing & Initialization
# Safely navigate to the infrastructure directory regardless of where the script 
# is executed from.
# ------------------------------------------------------------------------------
cd "$(dirname "$0")/../infra"

echo ""
echo "[3/5] Connecting to remote state backend..."
terraform init -reconfigure -backend-config="storage_account_name=$STORAGE_ACCOUNT_NAME"

# ------------------------------------------------------------------------------
# STEP 4: Safe Infrastructure Destruction (The Muscle)
# Here we mitigate the "Orphaned Infrastructure" incident. We create a dummy SSH
# key so Terraform can successfully evaluate the state without crashing locally.
# ------------------------------------------------------------------------------
echo ""
echo "[4/5] Evaluating infrastructure to destroy..."

# SRE Fix: Create dummy file to satisfy Terraform's file() function during plan
touch ephemeral_ssh_key.pub

# Create the destruction plan
terraform plan -destroy -out=destroy.tfplan

echo ""
echo "Executing Terraform Destroy (Infrastructure)..."
# Destroy the actual compute resources (VM, VNet, NSG)
terraform apply -auto-approve destroy.tfplan

# Clean up the dummy key
rm ephemeral_ssh_key.pub

# ------------------------------------------------------------------------------
# STEP 5: Deep Clean the State Backend (The Brain)
# Once Terraform has destroyed the infrastructure, we safely delete the state 
# resource group to ensure zero lingering costs.
# ------------------------------------------------------------------------------
echo ""
echo "[5/5] Deep Clean: Removing Terraform State Resource Group..."
# Delete the resource group in the background without locking the terminal
az group delete --name "rg-secureops-tfstate" --yes --no-wait

echo ""
echo "=== Complete Teardown Finished. Your Azure environment is clean. ==="