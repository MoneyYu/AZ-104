resource "azurerm_cdn_frontdoor_profile" "lab06e" {
  name                = "${local.lab06e_name}-fd-${local.random_str}"
  resource_group_name = azurerm_resource_group.az104.name
  sku_name            = "Standard_AzureFrontDoor"
  tags                = local.default_tags
}

resource "azurerm_cdn_frontdoor_endpoint" "lab06e" {
  name                     = "${local.lab06e_name}-fd-endpoint-${local.random_str}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.lab06e.id
  tags                     = local.default_tags
}

resource "azurerm_cdn_frontdoor_origin_group" "lab06e" {
  name                     = "${local.lab06e_name}-fd-origin-group-${local.random_str}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.lab06e.id
  session_affinity_enabled = true

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }

  health_probe {
    path                = "/"
    request_type        = "HEAD"
    protocol            = "Https"
    interval_in_seconds = 100
  }
}

resource "azurerm_cdn_frontdoor_origin" "lab06e" {
  name                          = "${local.lab06e_name}-fd-origin-${local.random_str}"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.lab06e.id

  enabled                        = true
  host_name                      = azurerm_windows_web_app.lab06e.default_hostname
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = azurerm_windows_web_app.lab06e.default_hostname
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true
}

resource "azurerm_cdn_frontdoor_route" "lab06e" {
  name                          = "${local.lab06e_name}-fd-route-${local.random_str}"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.lab06e.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.lab06e.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.lab06e.id]

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/*"]
  forwarding_protocol    = "HttpsOnly"
  link_to_default_domain = true
  https_redirect_enabled = true
}

resource "azurerm_service_plan" "lab06e" {
  name                = "${local.lab06e_name}-app-plan-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  sku_name     = "S1"
  os_type      = "Windows"
  worker_count = 1
  tags         = local.default_tags
}

resource "azurerm_windows_web_app" "lab06e" {
  name                = "${local.lab06e_name}-web-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  service_plan_id     = azurerm_service_plan.lab06e.id

  https_only = true

  site_config {
    ftps_state          = "Disabled"
    minimum_tls_version = "1.2"
    ip_restriction {
      service_tag               = "AzureFrontDoor.Backend"
      ip_address                = null
      virtual_network_subnet_id = null
      action                    = "Allow"
      priority                  = 100
      headers {
        x_azure_fdid      = [azurerm_cdn_frontdoor_profile.lab06e.resource_guid]
        x_fd_health_probe = []
        x_forwarded_for   = []
        x_forwarded_host  = []
      }
      name = "Allow traffic from Front Door"
    }
  }
  tags = local.default_tags
}