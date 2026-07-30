# infra/providers.tf

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100" # Recommended stable version
    }
  }
}

# This is the mandatory block required by the Azure provider
provider "azurerm" {
  features {} 
  
  # Instruct Terraform to use federated identity (OIDC)
  use_oidc = true 

  # Skip automatic registration to prevent hangs on restricted subscriptions
  skip_provider_registration = true
}