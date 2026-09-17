## LAB-06-F-NETWORK-WATCHER

# 訂閱在每個區域會自動建立 Network Watcher(位於 NetworkWatcherRG),
# 這裡只以資料來源引用既有執行個體,避免 Terraform 建立或刪除該共用資源。
data "azurerm_network_watcher" "japaneast" {
  name                = "NetworkWatcher_${local.location}"
  resource_group_name = "NetworkWatcherRG"
}

# VNet flow log 的儲存目的地。租戶政策要求 Entra ID 驗證,因此停用存取金鑰,
# flow log 與講師存取都改走 RBAC。
resource "azurerm_storage_account" "lab06f" {
  provider = azurerm.storage_no_data_plane

  name                            = "${local.lab06f_name}stor${local.random_str}"
  location                        = azurerm_resource_group.az104.location
  resource_group_name             = azurerm_resource_group.az104.name
  account_tier                    = "Standard"
  account_kind                    = "StorageV2"
  account_replication_type        = "LRS"
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  tags                            = local.default_tags
}

# 停用存取金鑰後,flow log 必須以使用者指派的受控識別寫入儲存體帳戶。
resource "azurerm_user_assigned_identity" "lab06f" {
  name                = "${local.lab06f_name}-flowlog-mi-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_role_assignment" "lab06f_flowlog_storage" {
  scope                            = azurerm_storage_account.lab06f.id
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = azurerm_user_assigned_identity.lab06f.principal_id
  skip_service_principal_aad_check = true
}

# 講師帳號需要資料平面權限,才能在入口網站直接瀏覽 insights-logs-flowlogflowevent 容器。
resource "azurerm_role_assignment" "lab06f_trainer_storage" {
  scope                = azurerm_storage_account.lab06f.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# azurerm_network_watcher_flow_log 無法指定使用者指派的受控識別,
# 在停用存取金鑰的儲存體帳戶上會失敗,因此改用 azapi 直接呼叫 flowLogs API。
resource "azapi_resource" "lab06f_flow_log" {
  type      = "Microsoft.Network/networkWatchers/flowLogs@2025-07-01"
  name      = "${local.lab06f_name}-vnet-flowlog-${local.random_str}"
  parent_id = data.azurerm_network_watcher.japaneast.id
  location  = azurerm_resource_group.az104.location
  tags      = local.default_tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.lab06f.id]
  }

  body = {
    properties = {
      targetResourceId = azurerm_virtual_network.lab06b.id
      storageId        = azurerm_storage_account.lab06f.id
      enabled          = true

      format = {
        type    = "JSON"
        version = 2
      }

      retentionPolicy = {
        enabled = true
        days    = 7
      }

      # Traffic Analytics 讓流量記錄進入共用工作區,可用 KQL 與流量地圖示範。
      flowAnalyticsConfiguration = {
        networkWatcherFlowAnalyticsConfiguration = {
          enabled                  = true
          workspaceId              = azurerm_log_analytics_workspace.vminsights.workspace_id
          workspaceRegion          = azurerm_log_analytics_workspace.vminsights.location
          workspaceResourceId      = azurerm_log_analytics_workspace.vminsights.id
          trafficAnalyticsInterval = 10
        }
      }
    }
  }

  depends_on = [azurerm_role_assignment.lab06f_flowlog_storage]
}

# 連線監視與連線疑難排解需要 VM 上安裝 Network Watcher Agent;
# 等待 outbound rule 建立後再裝,代理程式才有對外連線可回報結果。
resource "azurerm_virtual_machine_extension" "lab06f_nwagent01" {
  name                       = "${local.lab06f_name}-nwagent-01-${local.random_str}"
  publisher                  = "Microsoft.Azure.NetworkWatcher"
  type                       = "NetworkWatcherAgentWindows"
  type_handler_version       = "1.4"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06b01.id
  tags                       = local.default_tags

  depends_on = [azurerm_lb_outbound_rule.lab06b]
}

resource "azurerm_virtual_machine_extension" "lab06f_nwagent02" {
  name                       = "${local.lab06f_name}-nwagent-02-${local.random_str}"
  publisher                  = "Microsoft.Azure.NetworkWatcher"
  type                       = "NetworkWatcherAgentWindows"
  type_handler_version       = "1.4"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06b02.id
  tags                       = local.default_tags

  depends_on = [azurerm_lb_outbound_rule.lab06b]
}

# 連線監視:VM → VM(內網)、VM → Application Gateway(跨 lab)、VM → 網際網路。
resource "azurerm_network_connection_monitor" "lab06f" {
  name               = "${local.lab06f_name}-connection-monitor-${local.random_str}"
  network_watcher_id = data.azurerm_network_watcher.japaneast.id
  location           = data.azurerm_network_watcher.japaneast.location

  endpoint {
    name               = "lab06b-vm01"
    target_resource_id = azurerm_windows_virtual_machine.lab06b01.id
  }

  endpoint {
    name               = "lab06b-vm02"
    target_resource_id = azurerm_windows_virtual_machine.lab06b02.id
  }

  endpoint {
    name    = "lab06c-appgw"
    address = azurerm_public_ip.lab06c.fqdn
  }

  endpoint {
    name    = "internet"
    address = "www.microsoft.com"
  }

  test_configuration {
    name                      = "tcp80"
    protocol                  = "Tcp"
    test_frequency_in_seconds = 60

    tcp_configuration {
      port = 80
    }
  }

  test_configuration {
    name                      = "tcp443"
    protocol                  = "Tcp"
    test_frequency_in_seconds = 60

    tcp_configuration {
      port = 443
    }
  }

  test_configuration {
    name                      = "icmp"
    protocol                  = "Icmp"
    test_frequency_in_seconds = 60

    icmp_configuration {
      trace_route_enabled = true
    }
  }

  test_group {
    name                     = "vm-to-vm"
    source_endpoints         = ["lab06b-vm01"]
    destination_endpoints    = ["lab06b-vm02"]
    test_configuration_names = ["tcp80", "icmp"]
  }

  test_group {
    name                     = "vm-to-appgw"
    source_endpoints         = ["lab06b-vm01", "lab06b-vm02"]
    destination_endpoints    = ["lab06c-appgw"]
    test_configuration_names = ["tcp80"]
  }

  test_group {
    name                     = "vm-to-internet"
    source_endpoints         = ["lab06b-vm01"]
    destination_endpoints    = ["internet"]
    test_configuration_names = ["tcp443"]
  }

  output_workspace_resource_ids = [azurerm_log_analytics_workspace.vminsights.id]

  tags = local.default_tags

  depends_on = [
    azurerm_virtual_machine_extension.lab06f_nwagent01,
    azurerm_virtual_machine_extension.lab06f_nwagent02,
  ]
}
