## LAB-9-B-ACI
resource "azurerm_container_registry" "lab09b" {
  name                = "${local.lab09b_name}acr${local.random_str}"
  resource_group_name = azurerm_resource_group.az104.name
  location            = azurerm_resource_group.az104.location
  sku                 = "Premium"
  admin_enabled       = true

  georeplications {
    location                = "East Asia"
    zone_redundancy_enabled = false
    tags                    = local.default_tags
  }

  georeplications {
    location                = "JapanWest"
    zone_redundancy_enabled = false
    tags                    = local.default_tags
  }

  georeplications {
    location                = "SouthEastAsia"
    zone_redundancy_enabled = false
    tags                    = local.default_tags
  }
  
  tags = local.default_tags
}

resource "azurerm_container_group" "lab09b" {
  name                = "${local.lab09b_name}-aci-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  ip_address_type     = "Public"
  dns_name_label      = "${local.lab09b_name}-aci-${local.random_str}"
  os_type             = "Linux"

  container {
    name   = "hello-world"
    image  = "mcr.microsoft.com/azuredocs/aci-helloworld:latest"
    cpu    = "1"
    memory = "2"

    ports {
      port     = 443
      protocol = "TCP"
    }

    ports {
      port     = 80
      protocol = "TCP"
    }
  }

  # container {
  #   name   = "sidecar"
  #   image  = "mcr.microsoft.com/azuredocs/aci-tutorial-sidecar"
  #   cpu    = "1"
  #   memory = "2"
  # }

  # container {
  #   name   = "hello-world"
  #   image  = "abc12207/simpleweb:latest"
  #   cpu    = "2"
  #   memory = "4"

  #   ports {
  #     port     = 80
  #     protocol = "TCP"
  #   }
  # }
  tags = local.default_tags
}
