## LAB-9-B-ACI
# Create Container Instance
resource "azurerm_container_group" "lab09b" {
  name                = local.lab09b_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  ip_address_type     = "public"
  dns_name_label      = local.lab09b_name_with_postfix
  os_type             = "Linux"

  container {
    name   = "hello-world"
    image  = "abc12207/simpleweb:latest"
    cpu    = "2"
    memory = "4"

    ports {
      port     = 80
      protocol = "TCP"
    }
  }

  tags = {
    environment = local.group_name
  }
}