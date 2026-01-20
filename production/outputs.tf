# =============================================================================
# Outputs - Production
# =============================================================================

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "storage_account_name" {
  value = azurerm_storage_account.cnpg_backups.name
}

output "kube_config_command" {
  value = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name} --file ~/.kube/azure-${var.environment}"
}

output "aks_csi_identity_client_id" {
  description = "Client ID for SecretProviderClass"
  value       = azurerm_kubernetes_cluster.main.key_vault_secrets_provider[0].secret_identity[0].client_id
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "gitops_identity_reminder" {
  value = <<-EOT

    ============================================================
    PRODUCTION: AKS Identity für SecretProviderClasses
    ============================================================

    userAssignedIdentityID: "${azurerm_kubernetes_cluster.main.key_vault_secrets_provider[0].secret_identity[0].client_id}"
    keyvaultName: "${azurerm_key_vault.main.name}"
    tenantId: "${data.azurerm_client_config.current.tenant_id}"

    ============================================================
  EOT
}
# trigger
