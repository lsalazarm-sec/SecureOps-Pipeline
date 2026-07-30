#!/bin/bash
# scripts/bootstrap.sh
# Purpose: Provision a zero-cost Azure backend for Terraform state and configure OIDC authentication for GitHub Actions.

# Variables
RESOURCE_GROUP="rg-secureops-tfstate"
LOCATION="eastus" # Chosen for general availability and low cost
STORAGE_ACCOUNT_NAME="stsecureops$RANDOM" # Ensures global uniqueness
CONTAINER_NAME="tfstate"
APP_NAME="github-actions-secureops"
REPO_NAME="lsalazarm-sec/SecureOps-Pipeline"

echo "[+] 1. Creating Resource Group: $RESOURCE_GROUP..."
az group create --name $RESOURCE_GROUP --location $LOCATION -o table

echo "[+] 2. Creating Storage Account: $STORAGE_ACCOUNT_NAME (Standard_LRS for minimal cost)..."
az storage account create --name $STORAGE_ACCOUNT_NAME --resource-group $RESOURCE_GROUP --location $LOCATION --sku Standard_LRS -o table

echo "[+] 3. Creating Storage Container: $CONTAINER_NAME..."
az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME --auth-mode login -o table

echo "[+] 4. Creating Entra ID App Registration for OIDC..."
APP_ID=$(az ad app create --display-name $APP_NAME --query appId -o tsv)
SP_ID=$(az ad sp create --id $APP_ID --query id -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Pause to allow Azure to replicate the newly created service principal
echo "[*] Waiting 15 seconds for identity replication..."
sleep 15 

echo "[+] 5. Assigning Contributor role to the Service Principal..."
az role assignment create --role contributor --subscription $SUBSCRIPTION_ID --assignee-object-id $SP_ID --assignee-principal-type ServicePrincipal --scope /subscriptions/$SUBSCRIPTION_ID -o table

echo "[+] 6. Configuring OIDC Federated Credentials for GitHub repo..."
cat <<EOF > cred.json
{
  "name": "SecureOps-GitHub",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${REPO_NAME}:ref:refs/heads/main",
  "description": "Secure access for GitHub Actions via OIDC",
  "audiences": ["api://AzureADTokenExchange"]
}
EOF
az ad app federated-credential create --id $APP_ID --parameters @cred.json
rm cred.json

echo ""
echo "=== SETUP COMPLETE ==="
echo "Take a screenshot of this output for your documentation."
echo "Add the following variables as Repository Secrets in GitHub (Settings -> Secrets and variables -> Actions):"
echo "AZURE_CLIENT_ID: $APP_ID"
echo "AZURE_TENANT_ID: $(az account show --query tenantId -o tsv)"
echo "AZURE_SUBSCRIPTION_ID: $SUBSCRIPTION_ID"
echo "TF_STATE_STORAGE_ACCOUNT: $STORAGE_ACCOUNT_NAME"
echo "======================"