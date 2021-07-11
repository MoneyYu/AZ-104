## LAB-09-A-WEBAPP
resource "azurerm_app_service_plan" "lab09a" {
  name                = local.lab09a_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_app_service" "lab09a" {
  name                = local.lab09a_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  app_service_plan_id = azurerm_app_service_plan.lab09a.id

  site_config {
    linux_fx_version = "DOTNETCORE|3.1"
  }
}

resource "azurerm_application_insights" "lab09a" {
  name                = local.lab09a_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  application_type    = "web"

  tags = {
    environment = local.group_name
  }
}