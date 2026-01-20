# =============================================================================
# Customer Module Outputs
# =============================================================================

output "customer_name" {
  value = var.customer_name
}

output "customer_namespace" {
  value = var.customer_name
}

output "customer_url" {
  value = "https://${var.customer_name}.${var.environment}.${var.domain}"
}

output "backup_container" {
  value = azurerm_storage_container.customer.name
}
