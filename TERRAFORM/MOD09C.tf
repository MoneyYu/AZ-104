## LAB-9-C-AKS

# =============================================================================
# 基礎監控資源
# =============================================================================

# Log Analytics Workspace — Container Insights + Diagnostic Setting 目的地
resource "azurerm_log_analytics_workspace" "lab09c" {
  name                = "${local.lab09c_name}-law-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.default_tags
}

# Azure Monitor Workspace — Managed Prometheus 指標儲存
resource "azurerm_monitor_workspace" "lab09c" {
  name                = "${local.lab09c_name}-amw-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

# =============================================================================
# AKS Cluster
# =============================================================================

resource "azurerm_kubernetes_cluster" "lab09c" {
  name                = "${local.lab09b_name}-aks-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  dns_prefix          = "${local.lab09b_name}-aks-${local.random_str}"

  automatic_upgrade_channel = "stable"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  # Container Insights — 收集容器日誌、KubeEvents、Inventory、InsightsMetrics
  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.lab09c.id
    msi_auth_for_monitoring_enabled = true
  }

  # Managed Prometheus — 收集 node/kubelet/kube-state/cAdvisor/CoreDNS 指標
  monitor_metrics {}

  tags = local.default_tags
}

# AcrPull 角色指派
resource "azurerm_role_assignment" "lab09c" {
  principal_id                     = azurerm_kubernetes_cluster.lab09c.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.lab09b.id
  skip_service_principal_aad_check = true
}

# =============================================================================
# Prometheus Data Collection Rule / Endpoint Association
# =============================================================================

resource "azurerm_monitor_data_collection_rule_association" "lab09c_dcr" {
  name                    = "${local.lab09c_name}-dcr-association"
  target_resource_id      = azurerm_kubernetes_cluster.lab09c.id
  data_collection_rule_id = azurerm_monitor_workspace.lab09c.default_data_collection_rule_id
  description             = "Association of DCR for Managed Prometheus with AKS"
}

resource "azurerm_monitor_data_collection_rule_association" "lab09c_dce" {
  target_resource_id          = azurerm_kubernetes_cluster.lab09c.id
  data_collection_endpoint_id = azurerm_monitor_workspace.lab09c.default_data_collection_endpoint_id
  description                 = "Association of DCE for Managed Prometheus with AKS"
}

# =============================================================================
# Azure Managed Grafana
# =============================================================================

resource "azurerm_dashboard_grafana" "lab09c" {
  name                  = "${local.lab09c_name}-grafana-${local.random_str}"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  grafana_major_version = 11
  sku                   = "Standard"

  identity {
    type = "SystemAssigned"
  }

  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.lab09c.id
  }

  tags = local.default_tags
}

# Grafana RBAC — 讀取 Monitor Workspace
resource "azurerm_role_assignment" "lab09c_grafana_reader" {
  principal_id                     = azurerm_dashboard_grafana.lab09c.identity[0].principal_id
  role_definition_name             = "Monitoring Reader"
  scope                            = azurerm_monitor_workspace.lab09c.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "lab09c_grafana_data_reader" {
  principal_id                     = azurerm_dashboard_grafana.lab09c.identity[0].principal_id
  role_definition_name             = "Monitoring Data Reader"
  scope                            = azurerm_monitor_workspace.lab09c.id
  skip_service_principal_aad_check = true
}

# Grafana RBAC — 讀取 VM Insights Log Analytics Workspace
resource "azurerm_role_assignment" "grafana_vminsights_reader" {
  principal_id                     = azurerm_dashboard_grafana.lab09c.identity[0].principal_id
  role_definition_name             = "Monitoring Reader"
  scope                            = azurerm_log_analytics_workspace.vminsights.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "grafana_vminsights_la_reader" {
  principal_id                     = azurerm_dashboard_grafana.lab09c.identity[0].principal_id
  role_definition_name             = "Log Analytics Reader"
  scope                            = azurerm_log_analytics_workspace.vminsights.id
  skip_service_principal_aad_check = true
}

# =============================================================================
# Diagnostic Setting — AKS 控制平面所有日誌 + 平台指標
# =============================================================================

resource "azurerm_monitor_diagnostic_setting" "lab09c" {
  name                       = "${local.lab09c_name}-diag"
  target_resource_id         = azurerm_kubernetes_cluster.lab09c.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.lab09c.id

  # API Server 日誌
  enabled_log { category = "kube-apiserver" }

  # 管理操作審計日誌（排除 GET/LIST，降低成本與日誌量）
  enabled_log { category = "kube-audit-admin" }

  # Controller Manager 日誌
  enabled_log { category = "kube-controller-manager" }

  # Scheduler 日誌
  enabled_log { category = "kube-scheduler" }

  # Cluster Autoscaler 日誌
  enabled_log { category = "cluster-autoscaler" }

  # Cloud Controller Manager 日誌
  enabled_log { category = "cloud-controller-manager" }

  # Microsoft Entra ID / Azure RBAC 審計
  enabled_log { category = "guard" }

  # CSI 控制器日誌
  enabled_log { category = "csi-azuredisk-controller" }
  enabled_log { category = "csi-azurefile-controller" }
  enabled_log { category = "csi-snapshot-controller" }

  # 所有平台指標
  enabled_metric { category = "AllMetrics" }
}
