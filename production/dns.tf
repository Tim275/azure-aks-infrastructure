# =============================================================================
# DNS Zone + Records - Production
# =============================================================================
# HINWEIS: Auskommentiert bis Domain gekauft wird!
#
# Zum Aktivieren:
# 1. Domain kaufen (z.B. bei Azure, Namecheap, Cloudflare)
# 2. enable_dns = true setzen
# 3. domain_name anpassen
# 4. terraform apply
# 5. Nameserver bei Domain-Registrar eintragen
# =============================================================================

variable "enable_dns" {
  description = "Enable DNS Zone and records"
  type        = bool
  default     = false # ← Auf true setzen wenn Domain gekauft
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "mercury.example.com" # ← Anpassen!
}

# =============================================================================
# Azure DNS Zone (nur wenn enable_dns = true)
# =============================================================================

# resource "azurerm_dns_zone" "main" {
#   count               = var.enable_dns ? 1 : 0
#   name                = var.domain_name
#   resource_group_name = azurerm_resource_group.main.name
# }

# =============================================================================
# DNS Records für Kunden (nur wenn enable_dns = true)
# =============================================================================

# A-Record für jeden Kunden → zeigt auf Traefik LoadBalancer IP
# resource "azurerm_dns_a_record" "customers" {
#   for_each            = var.enable_dns ? local.customers : toset([])
#   name                = each.key  # z.B. "cicero" → cicero.mercury.example.com
#   zone_name           = azurerm_dns_zone.main[0].name
#   resource_group_name = azurerm_resource_group.main.name
#   ttl                 = 300
#   records             = [data.kubernetes_service.traefik.status[0].load_balancer[0].ingress[0].ip]
# }

# Wildcard Record für alle Subdomains
# resource "azurerm_dns_a_record" "wildcard" {
#   count               = var.enable_dns ? 1 : 0
#   name                = "*"
#   zone_name           = azurerm_dns_zone.main[0].name
#   resource_group_name = azurerm_resource_group.main.name
#   ttl                 = 300
#   records             = [data.kubernetes_service.traefik.status[0].load_balancer[0].ingress[0].ip]
# }

# =============================================================================
# Output: Nameserver (für Domain-Registrar)
# =============================================================================

# output "dns_nameservers" {
#   description = "Nameserver für Domain-Registrar"
#   value       = var.enable_dns ? azurerm_dns_zone.main[0].name_servers : []
# }

# output "dns_zone_info" {
#   value = var.enable_dns ? <<-EOT
#
#     ============================================================
#     DNS ZONE ERSTELLT
#     ============================================================
#
#     Domain: ${var.domain_name}
#
#     Nameserver bei Domain-Registrar eintragen:
#     ${join("\n    ", azurerm_dns_zone.main[0].name_servers)}
#
#     Nach DNS-Propagation (ca. 10-30 Min):
#     - https://cicero.${var.domain_name}
#     - https://grafana.${var.domain_name}
#
#     ============================================================
#   EOT : "DNS nicht aktiviert (enable_dns = false)"
# }
