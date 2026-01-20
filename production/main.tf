# =============================================================================
# Phase 11 Enterprise - Production Environment
# Based on staging with production-ready settings
# =============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }

  # Remote State - eigener Key für Production
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstate006c9d51"
    container_name       = "tfstate"
    key                  = "phase-11/production.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# =============================================================================
# Variables
# =============================================================================

variable "subscription_id" {
  description = "Azure Subscription ID (use TF_VAR_subscription_id or -var)"
  type        = string
}

variable "location" {
  description = "Azure Region"
  type        = string
  default     = "northeurope"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.32"
}

variable "gitops_repo_url" {
  description = "GitOps repository SSH URL"
  type        = string
  default     = "git@github.com:Tim275/mercury-gitops-v2.git"
}

variable "gitops_ssh_key_path" {
  description = "Path to SSH private key for GitOps"
  type        = string
  default     = "~/.ssh/mercury-gitops-v2"
}

variable "gitops_repo_local_path" {
  description = "Local path to GitOps repository"
  type        = string
  default     = "/Users/timour/Desktop/Devops2-Azure/mercury-gitops-v2"
}

variable "aks_admin_group_id" {
  description = "Azure AD Object ID for AKS admin access (user or group)"
  type        = string
  default     = "21d94cdd-6a68-4295-85bf-9f6d773541f4" # Tim's Azure AD Object ID
}

# =============================================================================
# Resource Group
# =============================================================================

resource "azurerm_resource_group" "main" {
  name     = "rg-mercury-${var.environment}"
  location = var.location
}

# =============================================================================
# AKS Cluster - Production Settings
# =============================================================================

resource "azurerm_kubernetes_cluster" "main" {
  name                = "mercury-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = var.environment
  kubernetes_version  = var.kubernetes_version

  # Automatic upgrades - patch level only for stability
  automatic_upgrade_channel = "patch"
  node_os_upgrade_channel   = "NodeImage"

  # System node pool - ONLY for critical Kubernetes components
  # PRODUCTION: Erhöhe node_count auf 2+ für HA wenn Budget erlaubt
  default_node_pool {
    name                         = "system"
    node_count                   = 1 # Erhöhe auf 2 für Production HA
    vm_size                      = "Standard_D2s_v3"
    only_critical_addons_enabled = true

    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  # Azure AD RBAC - kubectl login via Azure AD
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    admin_group_object_ids = [var.aks_admin_group_id]
  }

  # Cilium CNI
  network_profile {
    network_plugin     = "azure"
    network_policy     = "cilium"
    network_data_plane = "cilium"
  }

  # CSI Secrets Store Provider
  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  # OIDC for Workload Identity
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # Maintenance windows - Sonntag Nacht
  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Sunday"
    start_time  = "02:00"
    utc_offset  = "+00:00"
  }

  maintenance_window_node_os {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Sunday"
    start_time  = "02:00"
    utc_offset  = "+00:00"
  }
}

# User Node Pool - for application workloads
# PRODUCTION: Erhöhe node_count auf 3+ für HA wenn Budget erlaubt
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = "Standard_D2s_v3"
  node_count            = 1 # Erhöhe auf 3 für Production HA

  upgrade_settings {
    max_surge = "33%"
  }
}

# =============================================================================
# Key Vault
# =============================================================================

data "azurerm_client_config" "current" {}

resource "random_string" "kv_suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "azurerm_key_vault" "main" {
  name                       = "kv-merc-${var.environment}-${random_string.kv_suffix.result}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  rbac_authorization_enabled = true

  depends_on = [azurerm_kubernetes_cluster.main]
}

resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "kv_aks_csi" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_kubernetes_cluster.main.key_vault_secrets_provider[0].secret_identity[0].object_id
}

# =============================================================================
# FluxCD Extension
# =============================================================================

resource "azurerm_kubernetes_cluster_extension" "flux" {
  name           = "flux"
  cluster_id     = azurerm_kubernetes_cluster.main.id
  extension_type = "microsoft.flux"

  configuration_settings = {
    "image-automation-controller.enabled" = "false"
    "image-reflector-controller.enabled"  = "false"
    "notification-controller.enabled"     = "true"
  }

  depends_on = [azurerm_kubernetes_cluster_node_pool.user]
}

# =============================================================================
# FluxCD Git Configuration
# =============================================================================

resource "azurerm_kubernetes_flux_configuration" "main" {
  name       = "flux-system"
  cluster_id = azurerm_kubernetes_cluster.main.id
  namespace  = "flux-system"
  scope      = "cluster"

  git_repository {
    url                      = var.gitops_repo_url
    reference_type           = "branch"
    reference_value          = "main"
    ssh_private_key_base64   = base64encode(file(pathexpand(var.gitops_ssh_key_path)))
    sync_interval_in_seconds = 60
  }

  kustomizations {
    name                       = "infra-controllers"
    path                       = "./infrastructure/controllers/${var.environment}"
    sync_interval_in_seconds   = 300
    garbage_collection_enabled = true
  }

  kustomizations {
    name                       = "infra-configs"
    path                       = "./infrastructure/configs/${var.environment}"
    sync_interval_in_seconds   = 300
    depends_on                 = ["infra-controllers"]
    garbage_collection_enabled = true
  }

  kustomizations {
    name                       = "cnpg-plugin"
    path                       = "./cnpg-plugin/${var.environment}"
    sync_interval_in_seconds   = 300
    depends_on                 = ["infra-configs"]
    garbage_collection_enabled = true
  }

  kustomizations {
    name                       = "apps"
    path                       = "./apps/${var.environment}"
    sync_interval_in_seconds   = 300
    depends_on                 = ["cnpg-plugin"]
    garbage_collection_enabled = true
  }

  kustomizations {
    name                       = "monitoring-controllers"
    path                       = "./monitoring/controllers/${var.environment}"
    sync_interval_in_seconds   = 300
    depends_on                 = ["apps"]
    garbage_collection_enabled = true
  }

  kustomizations {
    name                       = "monitoring-configs"
    path                       = "./monitoring/configs/${var.environment}"
    sync_interval_in_seconds   = 300
    depends_on                 = ["monitoring-controllers"]
    garbage_collection_enabled = true
  }

  depends_on = [
    azurerm_kubernetes_cluster_extension.flux,
    time_sleep.wait_for_git_propagation
  ]
}

# =============================================================================
# Grafana Admin Credentials
# =============================================================================
# Checkov CKV_AZURE_41: Secrets have expiration dates
# Checkov CKV_AZURE_114: Secrets have content_type set
# =============================================================================

locals {
  # Secret expiration: 2 years from now (enterprise standard)
  secret_expiration = timeadd(timestamp(), "17520h")
}

resource "random_password" "grafana_admin" {
  length  = 24
  special = false

  lifecycle {
    ignore_changes = all
  }
}

resource "azurerm_key_vault_secret" "grafana_admin_password" {
  name            = "grafana-admin-password"
  value           = random_password.grafana_admin.result
  key_vault_id    = azurerm_key_vault.main.id
  content_type    = "text/plain"
  expiration_date = local.secret_expiration

  lifecycle {
    ignore_changes = [expiration_date]
  }

  depends_on = [azurerm_role_assignment.kv_admin]
}

resource "azurerm_key_vault_secret" "grafana_admin_user" {
  name            = "grafana-admin-user"
  value           = "admin"
  key_vault_id    = azurerm_key_vault.main.id
  content_type    = "text/plain"
  expiration_date = local.secret_expiration

  lifecycle {
    ignore_changes = [expiration_date]
  }

  depends_on = [azurerm_role_assignment.kv_admin]
}

# =============================================================================
# Grafana Telegram Credentials (Dummy Values - Replace via az keyvault secret set)
# =============================================================================

# NOTE: Telegram credentials are EXTERNAL - must be set manually after deployment:
# az keyvault secret set --vault-name <VAULT_NAME> --name grafana-telegram-bot-token --value <YOUR_BOT_TOKEN>
# az keyvault secret set --vault-name <VAULT_NAME> --name grafana-telegram-chat-id --value <YOUR_CHAT_ID>

resource "azurerm_key_vault_secret" "grafana_telegram_bot_token" {
  name            = "grafana-telegram-bot-token"
  value           = "CONFIGURE_VIA_AZ_CLI"
  key_vault_id    = azurerm_key_vault.main.id
  content_type    = "application/x-telegram-token"
  expiration_date = local.secret_expiration

  lifecycle {
    ignore_changes = [value, expiration_date]
  }

  depends_on = [azurerm_role_assignment.kv_admin]
}

resource "azurerm_key_vault_secret" "grafana_telegram_chat_id" {
  name            = "grafana-telegram-chat-id"
  value           = "CONFIGURE_VIA_AZ_CLI"
  key_vault_id    = azurerm_key_vault.main.id
  content_type    = "application/x-telegram-chat-id"
  expiration_date = local.secret_expiration

  lifecycle {
    ignore_changes = [value, expiration_date]
  }

  depends_on = [azurerm_role_assignment.kv_admin]
}

# =============================================================================
# Grafana SecretProviderClass
# =============================================================================

resource "local_file" "grafana_secrets" {
  filename = "${var.gitops_repo_local_path}/monitoring/configs/${var.environment}/grafana-secrets.yaml"
  content  = <<-YAML
    # Generated by Terraform - DO NOT EDIT MANUALLY
    apiVersion: secrets-store.csi.x-k8s.io/v1
    kind: SecretProviderClass
    metadata:
      name: grafana-secrets
      namespace: monitoring
    spec:
      provider: azure
      parameters:
        usePodIdentity: "false"
        useVMManagedIdentity: "true"
        userAssignedIdentityID: "${azurerm_kubernetes_cluster.main.key_vault_secrets_provider[0].secret_identity[0].client_id}"
        keyvaultName: "${azurerm_key_vault.main.name}"
        tenantId: "${data.azurerm_client_config.current.tenant_id}"
        objects: |
          array:
            - |
              objectName: grafana-admin-user
              objectType: secret
            - |
              objectName: grafana-admin-password
              objectType: secret
      secretObjects:
        - secretName: grafana-keyvault-creds
          type: Opaque
          data:
            - objectName: grafana-admin-user
              key: admin-user
            - objectName: grafana-admin-password
              key: admin-password
  YAML

  depends_on = [
    azurerm_key_vault_secret.grafana_admin_user,
    azurerm_key_vault_secret.grafana_admin_password
  ]
}
