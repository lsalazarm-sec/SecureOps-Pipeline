# infra/providers.tf

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }

  # Partial backend configuration
  backend "azurerm" {
    resource_group_name  = "rg-secureops-tfstate"
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
    use_oidc             = true
    # storage_account_name is purposely omitted to be injected via CI/CD
  }
}

provider "azurerm" {
  features {} 
  use_oidc = true 
  skip_provider_registration = true
}