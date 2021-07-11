## LAB-06-A-ROUTE-TABLE
resource "azurerm_route_table" "lab06a" {
  name                          = local.lab06a_name_with_postfix
  location                      = azurerm_resource_group.az104.location
  resource_group_name           = azurerm_resource_group.az104.name
  disable_bgp_route_propagation = false

  route {
    name           = "route1"
    address_prefix = "10.0.0.0/16"
    next_hop_type  = "vnetlocal"
  }
}