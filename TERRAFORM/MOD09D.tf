## LAB-9-D-ACA (Azure Container Apps)

# =============================================================================
# Log Analytics Workspace — Container Apps 環境日誌目的地
# =============================================================================
resource "azurerm_log_analytics_workspace" "lab09d" {
  name                = "${local.lab09d_name}-law-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.default_tags
}

# =============================================================================
# Container Apps Environment
# =============================================================================
resource "azurerm_container_app_environment" "lab09d" {
  name                       = "${local.lab09d_name}-aca-env-${local.random_str}"
  location                   = azurerm_resource_group.az104.location
  resource_group_name        = azurerm_resource_group.az104.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.lab09d.id
  tags                       = local.default_tags
}

# =============================================================================
# Container App — 範例應用
# 原 MOD09D-issue.tf 使用 azapi_update_resource，目的僅是把 Dapr 的 appPort
# PATCH 成 null（azurerm 原生 dapr 區塊無法表示 null：AppPort 為 int64，省略時會
# 送出 0 而非 null）。Dapr 不在 AZ-104（Azure 系統管理員）課程範圍內，因此此 demo
# 移除 Dapr，改為單純的 Container Apps 部署示範，完全不需要 azapi provider。
# =============================================================================
resource "azurerm_container_app" "lab09d" {
  name                         = "${local.lab09d_name}-app-${local.random_str}"
  container_app_environment_id = azurerm_container_app_environment.lab09d.id
  resource_group_name          = azurerm_resource_group.az104.name
  revision_mode                = "Single"
  tags                         = local.default_tags

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "hello-world"
      image  = "mcr.microsoft.com/k8se/quickstart:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  ingress {
    external_enabled = true
    target_port      = 80
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  lifecycle {
    ignore_changes = [tags]
  }
}
