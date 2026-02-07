# =============================================================================
# Storage Account for CNPG Backups - Production
# =============================================================================

resource "azurerm_storage_account" "cnpg_backups" {
  name                     = "mercurybackupsprod"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "GRS" # Production: Geo-Redundant für Disaster Recovery
  min_tls_version          = "TLS1_2"

  blob_properties {
    versioning_enabled = true
  }
}

# Storage account name in Key Vault
resource "azurerm_key_vault_secret" "storage_account_name" {
  name         = "storage-account-name"
  value        = azurerm_storage_account.cnpg_backups.name
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_role_assignment.kv_admin]
}
