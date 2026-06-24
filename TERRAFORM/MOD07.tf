## LAB-07-STORAGE
resource "azurerm_storage_account" "lab07" {
  name                     = "${local.lab07_name}stor${local.random_str}"
  resource_group_name      = azurerm_resource_group.az104.name
  location                 = azurerm_resource_group.az104.location
  account_tier             = "Standard"
  account_replication_type = "RAGRS"
  tags                     = local.default_tags
}

resource "azurerm_monitor_diagnostic_setting" "lab07_blob" {
  name                       = "lab07-blob-diag"
  target_resource_id         = "${azurerm_storage_account.lab07.id}/blobServices/default"
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

resource "azurerm_monitor_diagnostic_setting" "lab07_file" {
  name                       = "lab07-file-diag"
  target_resource_id         = "${azurerm_storage_account.lab07.id}/fileServices/default"
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

resource "azurerm_monitor_diagnostic_setting" "lab07_queue" {
  name                       = "lab07-queue-diag"
  target_resource_id         = "${azurerm_storage_account.lab07.id}/queueServices/default"
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

resource "azurerm_monitor_diagnostic_setting" "lab07_table" {
  name                       = "lab07-table-diag"
  target_resource_id         = "${azurerm_storage_account.lab07.id}/tableServices/default"
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
