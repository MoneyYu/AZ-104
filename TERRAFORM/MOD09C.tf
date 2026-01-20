## LAB-9-C-AKS
resource "azurerm_kubernetes_cluster" "lab09c" {
  name                = "${local.lab09b_name}-aks-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  dns_prefix          = "${local.lab09b_name}-aks-${local.random_str}"

  automatic_channel_upgrade = "stable"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }
  tags = local.default_tags
}

resource "azurerm_role_assignment" "lab09c" {
  principal_id                     = azurerm_kubernetes_cluster.lab09c.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.lab09b.id
  skip_service_principal_aad_check = true
}
