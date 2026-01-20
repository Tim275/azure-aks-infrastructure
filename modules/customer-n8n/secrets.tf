# =============================================================================
# Customer Secrets in Key Vault - Enterprise Compliant
# =============================================================================
# Checkov CKV_AZURE_41: Secrets have expiration dates
# Checkov CKV_AZURE_114: Secrets have content_type set
# =============================================================================

locals {
  # Secret expiration: 2 years from now (enterprise standard)
  secret_expiration = timeadd(timestamp(), "17520h")
}

# Database credentials
resource "random_password" "db_password" {
  length  = 24
  special = false

  lifecycle {
    ignore_changes = all
  }
}

resource "azurerm_key_vault_secret" "db_user" {
  name            = "${var.customer_name}-db-user"
  value           = "app"
  key_vault_id    = var.key_vault_id
  content_type    = "text/plain"
  expiration_date = local.secret_expiration

  lifecycle {
    ignore_changes = [expiration_date]
  }
}

resource "azurerm_key_vault_secret" "db_password" {
  name            = "${var.customer_name}-db-password"
  value           = random_password.db_password.result
  key_vault_id    = var.key_vault_id
  content_type    = "text/plain"
  expiration_date = local.secret_expiration

  lifecycle {
    ignore_changes = [expiration_date]
  }
}

# Backup SAS token
resource "azurerm_key_vault_secret" "blob_sas" {
  name            = "${var.customer_name}-blob-sas"
  value           = data.azurerm_storage_account_blob_container_sas.customer.sas
  key_vault_id    = var.key_vault_id
  content_type    = "application/x-sas-token"
  expiration_date = local.secret_expiration

  lifecycle {
    ignore_changes = [expiration_date]
  }
}

# Telegram credentials - EXTERNAL, must be set manually after deployment:
# az keyvault secret set --vault-name <VAULT_NAME> --name <customer>-telegram-bot-token --value <TOKEN>
# az keyvault secret set --vault-name <VAULT_NAME> --name <customer>-telegram-chat-id --value <CHAT_ID>
resource "azurerm_key_vault_secret" "telegram_bot_token" {
  name            = "${var.customer_name}-telegram-bot-token"
  value           = "CONFIGURE_VIA_AZ_CLI"
  key_vault_id    = var.key_vault_id
  content_type    = "application/x-telegram-token"
  expiration_date = local.secret_expiration

  lifecycle {
    ignore_changes = [value, expiration_date]
  }
}

resource "azurerm_key_vault_secret" "telegram_chat_id" {
  name            = "${var.customer_name}-telegram-chat-id"
  value           = "CONFIGURE_VIA_AZ_CLI"
  key_vault_id    = var.key_vault_id
  content_type    = "application/x-telegram-chat-id"
  expiration_date = local.secret_expiration

  lifecycle {
    ignore_changes = [value, expiration_date]
  }
}
