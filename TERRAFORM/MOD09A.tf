## LAB-09-A-WEBAPP
resource "azurerm_service_plan" "lab09a" {
  name                = "${local.lab09a_name}-app-plan-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  os_type             = "Windows"
  sku_name            = "S1"

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_windows_web_app" "lab09a" {
  name                = "${local.lab09a_name}-web-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  service_plan_id     = azurerm_service_plan.lab09a.id

  site_config {
    application_stack {
      current_stack  = "dotnet"
      dotnet_version = "v6.0"
    }
  }

  tags = {
    environment = local.group_name
  }
}
