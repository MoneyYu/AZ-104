## LAB-9-C-AKS
resource "azurerm_kubernetes_cluster" "lab09c" {
  name                = local.lab09c_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  dns_prefix          = local.lab09c_name

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  addon_profile {
    aci_connector_linux {
      enabled = false
    }

    azure_policy {
      enabled = false
    }

    http_application_routing {
      enabled = false
    }

    oms_agent {
      enabled = false
    }
  }

  tags = {
    environment = local.group_name
  }
}
