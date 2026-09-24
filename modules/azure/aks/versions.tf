terraform {
  required_version = ">= 1.3"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # azurerm_federated_identity_credential.user_assigned_identity_id
      # arrived in 4.70; 5.0 drops the default pool arguments used here.
      version = ">= 4.70, < 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }
}
