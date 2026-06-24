## LAB-09-A-WEBAPP
resource "azurerm_service_plan" "lab09a" {
  name                = "${local.lab09a_name}-app-plan-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  os_type             = "Windows"
  sku_name            = "S1"
  tags                = local.default_tags
}

resource "azurerm_windows_web_app" "lab09a" {
  name                = "${local.lab09a_name}-web-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  service_plan_id     = azurerm_service_plan.lab09a.id

  site_config {
    application_stack {
      current_stack  = "dotnet"
      dotnet_version = "v10.0"
    }
  }
  tags = local.default_tags
}

resource "azurerm_monitor_diagnostic_setting" "lab09a_windows_web_app" {
  name                       = "${local.lab09a_name}-web-diag"
  target_resource_id         = azurerm_windows_web_app.lab09a.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_log {
    category = "AppServiceHTTPLogs"
  }

  enabled_log {
    category = "AppServiceConsoleLogs"
  }

  enabled_log {
    category = "AppServiceAppLogs"
  }

  enabled_log {
    category = "AppServiceAuditLogs"
  }

  enabled_log {
    category = "AppServiceIPSecAuditLogs"
  }

  enabled_log {
    category = "AppServicePlatformLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab09a_service_plan" {
  name                       = "${local.lab09a_name}-app-plan-diag"
  target_resource_id         = azurerm_service_plan.lab09a.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_metric {
    category = "AllMetrics"
  }
}
