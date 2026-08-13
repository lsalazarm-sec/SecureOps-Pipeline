# ==============================================================================
# AZURE RESOURCE MANAGER (azurerm) PROVIDER CONFIGURATION
# ==============================================================================
# Note: Authentication mechanisms (like use_oidc = true) are intentionally 
# excluded from this codebase. All OIDC authentication and state locks are 
# handled dynamically by the CI/CD pipeline via environment variables 
# (e.g., ARM_USE_OIDC=true, ARM_CLIENT_ID) to enforce a Zero-Touch deployment.

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      
      # Locked to v4.x to ensure stability and prevent breaking changes.
      # v4 deprecates 'use_oidc' and changes the registration syntax.
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  # The features block is strictly required by the azurerm provider, 
  # even when left empty, to customize the behavior of specific resources.
  features {} 

  # Standardized v4.x syntax to skip automatic provider registration.
  # Prevents Terraform from attempting to register all resource providers 
  # across the Azure subscription, which typically causes authorization 
  # failures in restricted CI/CD runner environments.
  resource_provider_registrations = "none" 
}
