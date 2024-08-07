## LAB-06-A-ROUTE-TABLE
resource "azurerm_route_table" "lab06a" {
  name                          = "${local.lab06a_name}-routes-${local.random_str}"
  location                      = azurerm_resource_group.az104.location
  resource_group_name           = azurerm_resource_group.az104.name

  route {
    name           = "route1"
    address_prefix = "10.0.0.0/16"
    next_hop_type  = "VnetLocal"
  }

  tags = {
    environment = local.group_name
  }
}