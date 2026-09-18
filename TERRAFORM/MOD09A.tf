## LAB-09-A-WEBAPP

# Windows code App Service 的 Azure Files 掛載需要共用金鑰。
# 本示範依賴既有的 SecurityControl = "Ignore" 政策豁免。
resource "azurerm_storage_account" "lab09a" {
  name                = "${local.lab09a_name}stor${local.random_str}"
  resource_group_name = azurerm_resource_group.az104.name
  location            = azurerm_resource_group.az104.location

  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  shared_access_key_enabled     = true
  public_network_access_enabled = true

  tags = local.default_tags
}

resource "azurerm_storage_share" "lab09a" {
  name               = "content"
  storage_account_id = azurerm_storage_account.lab09a.id
  quota              = 5
}

resource "azurerm_storage_share_file" "lab09a_index" {
  name              = "index.html"
  storage_share_url = azurerm_storage_share.lab09a.url
  source            = "${path.module}/FILES/lab09a/index.html"
  content_type      = "text/html; charset=utf-8"
}

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

  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  site_config {
    application_stack {
      current_stack  = "dotnet"
      dotnet_version = "v10.0"
    }
  }

  storage_account {
    name         = "content"
    type         = "AzureFiles"
    account_name = azurerm_storage_account.lab09a.name
    share_name   = azurerm_storage_share.lab09a.name
    access_key   = azurerm_storage_account.lab09a.primary_access_key
    mount_path   = "/mounts/content"
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

resource "azurerm_monitor_diagnostic_setting" "lab09a_storage_blob" {
  name                       = "lab09a-blob-diag"
  target_resource_id         = "${azurerm_storage_account.lab09a.id}/blobServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  enabled_metric {
    category = "Transaction"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab09a_storage_file" {
  name                       = "lab09a-file-diag"
  target_resource_id         = "${azurerm_storage_account.lab09a.id}/fileServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  enabled_metric {
    category = "Transaction"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab09a_storage_queue" {
  name                       = "lab09a-queue-diag"
  target_resource_id         = "${azurerm_storage_account.lab09a.id}/queueServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  enabled_metric {
    category = "Transaction"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab09a_storage_table" {
  name                       = "lab09a-table-diag"
  target_resource_id         = "${azurerm_storage_account.lab09a.id}/tableServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  enabled_metric {
    category = "Transaction"
  }
}
