## LAB-10-BACKUP
resource "azurerm_recovery_services_vault" "lab10" {
  name                = "${local.lab10_name}-recovery-vault-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  sku                 = "Standard"

  tags = local.default_tags
}