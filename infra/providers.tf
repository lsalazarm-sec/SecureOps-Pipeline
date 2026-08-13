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
      version = "~> 4.0"
    }
  }

  # ============================================================================
  # REMOTE STATE BACKEND
  # Description: Enforces remote state storage to prevent orphaned resources.
  # The storage_account_name is intentionally omitted here as it is injected 
  # dynamically by the CI/CD pipeline via -backend-config.
  # ============================================================================
  backend "azurerm" {
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {} 
  resource_provider_registrations = "none" 
}
