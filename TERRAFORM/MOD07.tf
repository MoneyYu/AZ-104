## LAB-07-STORAGE

# 租戶政策要求 Entra ID 驗證,因此停用存取金鑰,講師示範改走 RBAC 資料平面角色。
resource "azurerm_storage_account" "lab07" {
  provider = azurerm.storage_no_data_plane

  name                            = "${local.lab07_name}stor${local.random_str}"
  resource_group_name             = azurerm_resource_group.az104.name
  location                        = azurerm_resource_group.az104.location
  account_tier                    = "Standard"
  account_replication_type        = "RAGRS"
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  tags                            = local.default_tags
}

# 講師帳號需要 Blob/File/Queue/Table 資料平面權限,才能在入口網站/REST 示範 M07 內容。
resource "azurerm_role_assignment" "lab07_trainer_blob" {
  scope                = azurerm_storage_account.lab07.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
  principal_type       = "User"
}

resource "azurerm_role_assignment" "lab07_trainer_file" {
  scope                = azurerm_storage_account.lab07.id
  role_definition_name = "Storage File Data Privileged Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
  principal_type       = "User"
}

resource "azurerm_role_assignment" "lab07_trainer_queue" {
  scope                = azurerm_storage_account.lab07.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
  principal_type       = "User"
}

resource "azurerm_role_assignment" "lab07_trainer_table" {
  scope                = azurerm_storage_account.lab07.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
  principal_type       = "User"
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
