# =============================================================================
# Customer List - Add names here to onboard new customers
# =============================================================================

locals {
  customers = toset([
    # "julius",       # Auskommentiert wegen vCPU Quota (nur 4 in North Europe)
    "cicero",
    # "newcustomer",  # Uncomment to add
  ])
}

# =============================================================================
# Customer n8n Module - Erstellt n8n + PostgreSQL pro Kunde
# =============================================================================

module "customers" {
  source   = "../modules/customer-n8n"
  for_each = local.customers

  customer_name = each.key
  environment   = var.environment

  # Azure Resources
  storage_account_id                        = azurerm_storage_account.cnpg_backups.id
  storage_account_name                      = azurerm_storage_account.cnpg_backups.name
  storage_account_primary_connection_string = azurerm_storage_account.cnpg_backups.primary_connection_string
  key_vault_id                              = azurerm_key_vault.main.id
  keyvault_name                             = azurerm_key_vault.main.name
  keyvault_tenant_id                        = data.azurerm_client_config.current.tenant_id

  # AKS Identity for SecretProviderClass
  aks_keyvault_identity_client_id = azurerm_kubernetes_cluster.main.key_vault_secrets_provider[0].secret_identity[0].client_id

  # GitOps
  gitops_repo_path = var.gitops_repo_local_path

  # ==========================================================================
  # STAGING SETTINGS - Lower resources, single replica (cost optimization)
  # ==========================================================================
  n8n_version        = "1.68.0" # Pinned version
  n8n_replicas       = 1        # Single replica (no HA needed for staging)
  n8n_memory_request = "256Mi"
  n8n_memory_limit   = "512Mi"
  n8n_cpu_request    = "100m"
  n8n_cpu_limit      = "500m"
  n8n_storage_size   = "5Gi"

  db_instances    = 2 # Minimum for CNPG (1 primary + 1 replica)
  db_storage_size = "5Gi"

  depends_on = [
    azurerm_role_assignment.kv_admin,
    azurerm_key_vault_secret.storage_account_name
  ]
}

# =============================================================================
# Generate apps/staging/kustomization.yaml with all customers
# =============================================================================

resource "local_file" "apps_kustomization" {
  filename = "${var.gitops_repo_local_path}/apps/${var.environment}/kustomization.yaml"
  content  = <<-YAML
    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization
    resources:
    %{for customer in local.customers~}
      - ${customer}
    %{endfor~}
  YAML

  depends_on = [module.customers]
}

# =============================================================================
# Auto-Push GitOps Changes BEFORE FluxCD starts syncing
# This ensures FluxCD always sees the latest generated files
# =============================================================================

resource "null_resource" "gitops_push" {
  # Re-run when customers change or Key Vault name changes (new deployment)
  triggers = {
    customers     = join(",", local.customers)
    keyvault_name = azurerm_key_vault.main.name
    timestamp     = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd ${var.gitops_repo_local_path}

      # Stage all changes including secrets
      git add -f apps/${var.environment}/*/secrets.yaml 2>/dev/null || true
      git add -f monitoring/configs/${var.environment}/grafana-secrets.yaml 2>/dev/null || true
      git add -A

      # Only commit if there are changes
      if ! git diff --staged --quiet; then
        git commit -m "Terraform: Update ${var.environment} manifests [automated]"
        git push
        echo "✅ GitOps changes pushed successfully"
      else
        echo "ℹ️ No changes to push"
      fi
    EOT
  }

  depends_on = [
    module.customers,
    local_file.apps_kustomization,
    local_file.grafana_secrets
  ]
}

# =============================================================================
# WICHTIG: Warte nach Git Push damit GitHub die Änderungen propagiert
# Verhindert Race Condition: FluxCD synct bevor die neuen Dateien auf GitHub sind
# =============================================================================

resource "time_sleep" "wait_for_git_propagation" {
  create_duration = "30s"

  triggers = {
    # Re-wait whenever gitops_push runs
    gitops_push_id = null_resource.gitops_push.id
  }

  depends_on = [null_resource.gitops_push]
}
