#!/bin/bash
# scripts/bootstrap.sh
# Purpose: Provision a zero-cost Azure backend for Terraform state.
# Note: OIDC identity federation is managed directly via Azure DevOps Service Connections.

# 1. Configuration Variables
RESOURCE_GROUP="rg-secureops-tfstate"
LOCATION="eastus" 
STORAGE_ACCOUNT_NAME="stsecureops$RANDOM" 
CONTAINER_NAME="tfstate"

echo "=== SECUREOPS PIPELINE: INFRASTRUCTURE BOOTSTRAP ==="

echo "[+] 1. Creating Resource Group: $RESOURCE_GROUP..."
az group create --name $RESOURCE_GROUP --location $LOCATION -o table

echo "[+] 2. Creating Storage Account: $STORAGE_ACCOUNT_NAME (Standard_LRS)..."
az storage account create \
  --name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  -o table

echo "[+] 3. Creating Storage Container: $CONTAINER_NAME..."
az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT_NAME \
  --auth-mode login \
  -o table

echo ""
echo "=================================================================="
echo "✅ SETUP COMPLETE: TERRAFORM BACKEND PROVISIONED"
echo "This serves as evidence of your secure backend creation."
echo "=================================================================="
echo "ACTION REQUIRED: Copy the following Storage Account Name."
echo "You will need it for your providers.tf file:"
echo ""
echo "STORAGE_ACCOUNT_NAME: $STORAGE_ACCOUNT_NAME"
echo ""
echo "=================================================================="