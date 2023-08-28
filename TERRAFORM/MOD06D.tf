resource "azurerm_traffic_manager_profile" "lab06d" {
  name                   = "${local.lab06d_name}-tfm-${local.random_str}"
  resource_group_name    = azurerm_resource_group.az104.name
  traffic_routing_method = "Performance"
  dns_config {
    relative_name = "${local.lab06d_name}-tfm-${local.random_str}"
    ttl           = 30
  }

  monitor_config {
    protocol                    = "HTTPS"
    port                        = 443
    path                        = "/"
    expected_status_code_ranges = ["200-202", "301-302"]
  }

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_traffic_manager_external_endpoint" "lab06d01" {
  profile_id        = azurerm_traffic_manager_profile.lab06d.id
  name              = "${local.lab06d_name}-tfm-endpoint-01-${local.random_str}"
  target            = "www.contoso.com"
  endpoint_location = "eastus"
  weight            = 50
}

resource "azurerm_traffic_manager_external_endpoint" "lab06d02" {
  profile_id        = azurerm_traffic_manager_profile.lab06d.id
  name              = "${local.lab06d_name}-tfm-endpoint-02-${local.random_str}"
  target            = "www.fabrikam.com"
  endpoint_location = "westus"
  weight            = 50
}
