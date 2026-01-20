# =============================================================================
# Customer Onboarding Module - Variables
# =============================================================================
# Enterprise: All variables have validation and sensible defaults
# =============================================================================

variable "customer_name" {
  description = "Customer name (lowercase, alphanumeric with hyphens only)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$", var.customer_name))
    error_message = "customer_name must be lowercase alphanumeric with hyphens, 2-63 characters"
  }
}

variable "environment" {
  description = "Environment (staging/production)"
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be 'staging' or 'production'"
  }
}

# =============================================================================
# Azure Resources
# =============================================================================

variable "storage_account_id" {
  description = "Storage account ID for backups"
  type        = string
}

variable "storage_account_name" {
  description = "Storage account name"
  type        = string
}

variable "storage_account_primary_connection_string" {
  description = "Storage account connection string"
  type        = string
  sensitive   = true
}

variable "key_vault_id" {
  description = "Key Vault ID"
  type        = string
}

variable "keyvault_name" {
  description = "Key Vault name"
  type        = string
}

variable "keyvault_tenant_id" {
  description = "Key Vault tenant ID"
  type        = string
}

variable "aks_keyvault_identity_client_id" {
  description = "AKS CSI Driver identity client ID"
  type        = string
}

variable "gitops_repo_path" {
  description = "Local path to GitOps repository"
  type        = string
}

# =============================================================================
# App Configuration - Enterprise Defaults
# =============================================================================

variable "n8n_version" {
  description = "n8n container version (NEVER use 'latest' in production!)"
  type        = string
  default     = "1.68.0" # Pinned version for reproducibility

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.n8n_version))
    error_message = "n8n_version must be semantic versioning (e.g., 1.68.0). Never use 'latest'!"
  }
}

variable "n8n_replicas" {
  description = "Number of n8n pod replicas (use 1 for staging, 2+ for production)"
  type        = number
  default     = 1

  validation {
    condition     = var.n8n_replicas >= 1 && var.n8n_replicas <= 10
    error_message = "n8n_replicas must be between 1 and 10"
  }
}

variable "n8n_memory_request" {
  description = "n8n memory request"
  type        = string
  default     = "256Mi"
}

variable "n8n_memory_limit" {
  description = "n8n memory limit"
  type        = string
  default     = "512Mi"
}

variable "n8n_cpu_request" {
  description = "n8n CPU request"
  type        = string
  default     = "100m"
}

variable "n8n_cpu_limit" {
  description = "n8n CPU limit"
  type        = string
  default     = "500m"
}

variable "db_instances" {
  description = "Number of PostgreSQL instances (use 2 for staging, 3+ for production HA)"
  type        = number
  default     = 2

  validation {
    condition     = var.db_instances >= 1 && var.db_instances <= 9
    error_message = "db_instances must be between 1 and 9"
  }
}

variable "db_storage_size" {
  description = "PostgreSQL storage size"
  type        = string
  default     = "5Gi"

  validation {
    condition     = can(regex("^[0-9]+Gi$", var.db_storage_size))
    error_message = "db_storage_size must be in Gi format (e.g., 5Gi, 10Gi)"
  }
}

variable "n8n_storage_size" {
  description = "n8n PVC storage size"
  type        = string
  default     = "5Gi"

  validation {
    condition     = can(regex("^[0-9]+Gi$", var.n8n_storage_size))
    error_message = "n8n_storage_size must be in Gi format (e.g., 5Gi, 10Gi)"
  }
}

variable "domain" {
  description = "Base domain for ingress (optional, for later when domain is purchased)"
  type        = string
  default     = "mercury.local"
}

# HINWEIS: Ingress ist in kustomization.yaml auskommentiert
# Zum Aktivieren: ingress.yaml in kustomization.yaml einkommentieren
