## LAB-07-STORAGE
resource "azurerm_storage_account" "lab07" {
  name                     = "${local.lab07_name}stor${local.random_str}"
  resource_group_name      = azurerm_resource_group.az104.name
  location                 = azurerm_resource_group.az104.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  allow_blob_public_access = true

  tags = {
    environment = local.group_name
  }
}