## LAB-10-BACKUP
resource "azurerm_recovery_services_vault" "lab10" {
  name                = local.lab10_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  sku                 = "Standard"

  soft_delete_enabled = false
}

resource "azurerm_storage_account" "lab10" {
  name                     = local.lab10_name_with_postfix
  resource_group_name      = azurerm_resource_group.az104.name
  location                 = azurerm_resource_group.az104.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  allow_blob_public_access = true

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_storage_share" "lab10" {
  name                 = local.lab10_name_with_postfix
  storage_account_name = azurerm_storage_account.lab10.name
  quota                = 50
}