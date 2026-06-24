terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "ffc7fbc7-3840-4835-ad88-4eb5015d7dac"
}

variable "group_postfix" {
  type = string
}

variable "user_name" {
  type    = string
  default = "demouser"
}

variable "user_password" {
  type    = string
  default = "Azuredemo2020"
}

locals {
  group_name    = "AZ104-${var.group_postfix}"
  location      = "japaneast"
  random_str    = "cat"
  vm_size       = "Standard_B4ms"
  lab01_name    = "lab01"
  lab02_name    = "lab02"
  lab03_name    = "lab03"
  lab04_name    = "lab04"
  lab04b_name   = "lab04b"
  lab05a_name   = "lab05a"
  lab05b_name   = "lab05b"
  lab05c_name   = "lab05c"
  lab05d_name   = "lab05d"
  lab06a_name   = "lab06a"
  lab06b_name   = "lab06b"
  lab06c_name   = "lab06c"
  lab06d_name   = "lab06d"
  lab06e_name   = "lab06e"
  lab07_name    = "lab07"
  lab08_name    = "lab08"
  lab09a_name   = "lab09a"
  lab09b_name   = "lab09b"
  lab09c_name   = "lab09c"
  lab09d_name   = "lab09d"
  lab10_name    = "lab10"
  lab11_name    = "lab11"
  lab11b_name   = "lab11b"
  user_name     = "demouser"
  user_password = "Azuredemo2020"

  default_tags = {
    environment     = local.group_name
    SecurityControl = "Ignore"
  }

  # myip = "1.2.3.4"  # 固定 IP 地址
}

data "http" "myip" {
  url = "https://ipv4.icanhazip.com"

  # use: data.http.myip.response_body
}

data "azurerm_client_config" "current" {}

resource "random_string" "rid" {
  length  = 3
  special = false
  numeric = false
  upper   = false
}

resource "random_integer" "rint" {
  min = 100
  max = 999
}

resource "random_pet" "petname" {
  keepers = {
    # Generate a new pet name each time we switch to a new AMI id
    ami_id = var.group_postfix
  }
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "az104" {
  name     = local.group_name
  location = local.location
  tags     = local.default_tags
}

# Demo Resource Group
# resource "azurerm_resource_group" "demo" {
#   name     = "Demo${var.group_postfix}"
#   location = local.location

#   tags = local.default_tags
# }

# =============================================================================
# VM Insights — Shared Monitoring Resources
# =============================================================================
resource "azurerm_log_analytics_workspace" "vminsights" {
  name                = "law-vminsights-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.default_tags
}

resource "azurerm_log_analytics_solution" "vminsights" {
  solution_name         = "VMInsights"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  workspace_resource_id = azurerm_log_analytics_workspace.vminsights.id
  workspace_name        = azurerm_log_analytics_workspace.vminsights.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/VMInsights"
  }

  # 租戶的標籤繼承 Policy 會自動補上 environment 標籤,且此資源型別對 tags 處理特殊,
  # 忽略 tags 變更以避免每次 plan 都出現差異。
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_monitor_data_collection_rule" "vminsights" {
  name                = "MSVMI-law-vminsights-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  kind                = "Windows"

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.vminsights.id
      name                  = "vminsights-dest-la"
    }

    # detailed metrics:guest 指標送到 Azure Monitor Metrics(Metrics Explorer / metric alert 可用)
    azure_monitor_metrics {
      name = "vminsights-dest-metrics"
    }
  }

  data_flow {
    streams      = ["Microsoft-InsightsMetrics"]
    destinations = ["vminsights-dest-la"]
  }

  # detailed metrics:同一份 guest 指標也送到 Azure Monitor Metrics
  data_flow {
    streams      = ["Microsoft-InsightsMetrics"]
    destinations = ["vminsights-dest-metrics"]
  }

  data_flow {
    streams      = ["Microsoft-ServiceMap"]
    destinations = ["vminsights-dest-la"]
  }

  # Windows 事件日誌(System / Application / Security)→ Log Analytics 的 Event 表
  data_flow {
    streams      = ["Microsoft-Event"]
    destinations = ["vminsights-dest-la"]
  }

  # 詳細 OS 效能計數器 → Log Analytics 的 Perf 表(比 InsightsMetrics 更細的計數器)
  data_flow {
    streams      = ["Microsoft-Perf"]
    destinations = ["vminsights-dest-la"]
  }

  # IIS W3C 存取日誌 → Log Analytics 的 W3CIISLog 表(VM 上跑 IIS,記錄每筆 HTTP 請求)
  data_flow {
    streams      = ["Microsoft-W3CIISLog"]
    destinations = ["vminsights-dest-la"]
  }

  data_sources {
    performance_counter {
      streams                       = ["Microsoft-InsightsMetrics"]
      sampling_frequency_in_seconds = 60
      counter_specifiers = [
        "\\VmInsights\\DetailedMetrics"
      ]
      name = "VMInsightsPerfCounters"
    }

    # 詳細 OS 效能計數器 → Microsoft-Perf(Log Analytics 的 Perf 表)
    performance_counter {
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60
      counter_specifiers = [
        "\\Processor Information(_Total)\\% Processor Time",
        "\\Memory\\Available MBytes",
        "\\Memory\\% Committed Bytes In Use",
        "\\LogicalDisk(_Total)\\% Free Space",
        "\\LogicalDisk(_Total)\\Avg. Disk sec/Read",
        "\\LogicalDisk(_Total)\\Avg. Disk sec/Write",
        "\\LogicalDisk(_Total)\\Disk Transfers/sec",
        "\\Network Interface(*)\\Bytes Total/sec",
        "\\System\\Processor Queue Length"
      ]
      name = "detailedPerfCounters"
    }

    extension {
      streams        = ["Microsoft-ServiceMap"]
      extension_name = "DependencyAgent"
      name           = "DependencyAgentDataSource"
    }

    # Windows 事件日誌:System / Application(Critical/Error/Warning)+ Security 登入稽核事件
    windows_event_log {
      streams = ["Microsoft-Event"]
      x_path_queries = [
        "Application!*[System[(Level=1 or Level=2 or Level=3)]]",
        "System!*[System[(Level=1 or Level=2 or Level=3)]]",
        "Security!*[System[(EventID=4624 or EventID=4625 or EventID=4634 or EventID=4648 or EventID=4672)]]"
      ]
      name = "eventLogsDataSource"
    }

    # IIS W3C 存取日誌(IIS 預設記錄路徑;VM 未跑 IIS 時此來源自動無資料,不影響其他)
    iis_log {
      streams         = ["Microsoft-W3CIISLog"]
      log_directories = ["C:\\inetpub\\logs\\LogFiles\\W3SVC1"]
      name            = "iisLogsDataSource"
    }
  }

  tags = local.default_tags

  depends_on = [azurerm_log_analytics_solution.vminsights]
}

# =============================================================================
# 訂閱層級 Activity Log → 中央 Log Analytics（AzureActivity 表）
# 讓 Monitor 章節可示範 Activity Log 查詢與警示的真實資料
# =============================================================================
resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  name                       = "activity-log-${var.group_postfix}"
  target_resource_id         = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_log { category = "Administrative" }
  enabled_log { category = "Security" }
  enabled_log { category = "ServiceHealth" }
  enabled_log { category = "Alert" }
  enabled_log { category = "Recommendation" }
  enabled_log { category = "Policy" }
  enabled_log { category = "Autoscale" }
  enabled_log { category = "ResourceHealth" }
}

# =============================================================================
# Recommended Alerts — 對應入口網站 VM 的「Enable recommended alerts」
# 採資源群組範圍的 multi-resource 警示:一條規則即涵蓋 RG 內所有 VM(現在與未來),
# 只參考恆在的 az104 RG 與 action group,符合 TERRAFORM/TEMP swap 機制。
# =============================================================================
variable "alert_email" {
  type        = string
  default     = "admin@devmtt.com"
  description = "建議警示 action group 的通知信箱"
}

resource "azurerm_monitor_action_group" "recommended" {
  name                = "AZ104-recommended-ag"
  resource_group_name = azurerm_resource_group.az104.name
  short_name          = "az104alert"

  # 只有在 alert_email 非空時才建立 email 接收者(其他講師可設為空字串停用,避免誤寄)
  dynamic "email_receiver" {
    for_each = var.alert_email != "" ? [1] : []
    content {
      name          = "trainer"
      email_address = var.alert_email
    }
  }

  tags = local.default_tags
}

locals {
  vm_recommended_alerts = {
    cpu = {
      metric = "Percentage CPU", agg = "Average", op = "GreaterThan", threshold = 80, sev = 3
      desc   = "VM CPU 使用率高於 80%"
    }
    available_memory = {
      metric = "Available Memory Bytes", agg = "Average", op = "LessThan", threshold = 1073741824, sev = 3
      desc   = "VM 可用記憶體低於 1 GiB"
    }
    os_disk_iops = {
      metric = "OS Disk IOPS Consumed Percentage", agg = "Average", op = "GreaterThan", threshold = 95, sev = 3
      desc   = "OS 磁碟 IOPS 使用率高於 95%"
    }
    data_disk_iops = {
      metric = "Data Disk IOPS Consumed Percentage", agg = "Average", op = "GreaterThan", threshold = 95, sev = 3
      desc   = "資料磁碟 IOPS 使用率高於 95%"
    }
    availability = {
      metric = "VmAvailabilityMetric", agg = "Average", op = "LessThan", threshold = 1, sev = 1
      desc   = "VM 可用性異常(VM 不可用)"
    }
  }
}

resource "azurerm_monitor_metric_alert" "vm_recommended" {
  for_each = local.vm_recommended_alerts

  name                     = "AZ104-VM-${each.key}"
  resource_group_name      = azurerm_resource_group.az104.name
  scopes                   = [azurerm_resource_group.az104.id]
  target_resource_type     = "Microsoft.Compute/virtualMachines"
  target_resource_location = local.location
  description              = each.value.desc
  severity                 = each.value.sev
  frequency                = "PT5M"
  window_size              = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = each.value.metric
    aggregation      = each.value.agg
    operator         = each.value.op
    threshold        = each.value.threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.recommended.id
  }

  tags = local.default_tags
}
