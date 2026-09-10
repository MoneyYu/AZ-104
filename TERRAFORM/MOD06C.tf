## LAB-06-C-APP-GATEWAY
locals {
  lab06c_bepool_name                 = "${local.lab06c_name}-appgw-bepool-${local.random_str}"
  lab06c_images_bepool_name          = "${local.lab06c_name}-appgw-images-bepool-${local.random_str}"
  lab06c_video_bepool_name           = "${local.lab06c_name}-appgw-video-bepool-${local.random_str}"
  lab06c_default_http_settings_name  = "${local.lab06c_name}-appgw-http-setting-${local.random_str}"
  lab06c_images_http_settings_name   = "${local.lab06c_name}-appgw-images-http-setting-${local.random_str}"
  lab06c_video_http_settings_name    = "${local.lab06c_name}-appgw-video-http-setting-${local.random_str}"
  lab06c_default_probe_name          = "${local.lab06c_name}-appgw-default-probe-${local.random_str}"
  lab06c_images_probe_name           = "${local.lab06c_name}-appgw-images-probe-${local.random_str}"
  lab06c_video_probe_name            = "${local.lab06c_name}-appgw-video-probe-${local.random_str}"
  lab06c_url_path_map_name           = "${local.lab06c_name}-appgw-url-path-map-${local.random_str}"
  lab06c_redirect_configuration_name = "${local.lab06c_name}-appgw-redirect-${local.random_str}"
  lab06c_small_vm_size               = "Standard_B2ms"
}

resource "azurerm_virtual_network" "lab06c" {
  name                = "${local.lab06c_name}-vnet-${local.random_str}"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_subnet" "lab06csub01" {
  name                 = "backend"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab06c.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_subnet" "lab06csub02" {
  name                 = "frontend"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab06c.name
  address_prefixes     = ["10.10.2.0/24"]
}

resource "azurerm_public_ip" "lab06c" {
  name                = "${local.lab06c_name}-pip-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${local.lab06c_name}-pip-${local.random_str}"
  tags                = local.default_tags

  lifecycle {
    ignore_changes = [ip_tags]
  }
}

resource "azurerm_application_gateway" "lab06c" {
  name                = "${local.lab06c_name}-appgw-${local.random_str}"
  resource_group_name = azurerm_resource_group.az104.name
  location            = azurerm_resource_group.az104.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "${local.lab06c_name}-appgw-ipconfig-${local.random_str}"
    subnet_id = azurerm_subnet.lab06csub02.id
  }

  frontend_port {
    name = "${local.lab06c_name}-appgw-port-${local.random_str}"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "${local.lab06c_name}-appgw-pip-config-${local.random_str}"
    public_ip_address_id = azurerm_public_ip.lab06c.id
  }

  backend_address_pool {
    name = local.lab06c_bepool_name
  }

  backend_address_pool {
    name = local.lab06c_images_bepool_name
  }

  backend_address_pool {
    name = local.lab06c_video_bepool_name
  }

  backend_http_settings {
    name                  = local.lab06c_default_http_settings_name
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
    probe_name            = local.lab06c_default_probe_name
  }

  backend_http_settings {
    name                  = local.lab06c_images_http_settings_name
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
    probe_name            = local.lab06c_images_probe_name
  }

  backend_http_settings {
    name                  = local.lab06c_video_http_settings_name
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
    probe_name            = local.lab06c_video_probe_name
  }

  http_listener {
    name                           = "${local.lab06c_name}-appgw-listener-${local.random_str}"
    frontend_ip_configuration_name = "${local.lab06c_name}-appgw-pip-config-${local.random_str}"
    frontend_port_name             = "${local.lab06c_name}-appgw-port-${local.random_str}"
    protocol                       = "Http"
  }

  probe {
    name                = local.lab06c_default_probe_name
    host                = "127.0.0.1"
    interval            = 30
    path                = "/"
    protocol            = "Http"
    timeout             = 30
    unhealthy_threshold = 3
  }

  probe {
    name                = local.lab06c_images_probe_name
    host                = "127.0.0.1"
    interval            = 30
    path                = "/images/"
    protocol            = "Http"
    timeout             = 30
    unhealthy_threshold = 3
  }

  probe {
    name                = local.lab06c_video_probe_name
    host                = "127.0.0.1"
    interval            = 30
    path                = "/"
    protocol            = "Http"
    timeout             = 30
    unhealthy_threshold = 3
  }

  redirect_configuration {
    name                 = local.lab06c_redirect_configuration_name
    redirect_type        = "Permanent"
    target_listener_name = "${local.lab06c_name}-appgw-listener-${local.random_str}"
    include_path         = false
    include_query_string = false
  }

  url_path_map {
    name                               = local.lab06c_url_path_map_name
    default_backend_address_pool_name  = local.lab06c_bepool_name
    default_backend_http_settings_name = local.lab06c_default_http_settings_name

    path_rule {
      name                       = "images"
      paths                      = ["/images", "/images/*"]
      backend_address_pool_name  = local.lab06c_images_bepool_name
      backend_http_settings_name = local.lab06c_images_http_settings_name
    }

    path_rule {
      name                       = "video"
      paths                      = ["/video", "/video/*"]
      backend_address_pool_name  = local.lab06c_video_bepool_name
      backend_http_settings_name = local.lab06c_video_http_settings_name
    }

    path_rule {
      name                        = "legacy"
      paths                       = ["/legacy", "/legacy/*"]
      redirect_configuration_name = local.lab06c_redirect_configuration_name
    }
  }

  request_routing_rule {
    name               = "${local.lab06c_name}-appgw-rule-${local.random_str}"
    rule_type          = "PathBasedRouting"
    http_listener_name = "${local.lab06c_name}-appgw-listener-${local.random_str}"
    url_path_map_name  = local.lab06c_url_path_map_name
    priority           = 100
  }
  tags = local.default_tags
}

resource "azurerm_network_security_group" "lab06c" {
  name                = "${local.lab06c_name}-nsg-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_network_security_rule" "lab06c" {
  name                        = "AllowHTTPFromAppGW"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "10.10.2.0/24"
  destination_port_range      = "80"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab06c.name
}

# Subnet-level NSG association for backend subnet (shared with existing NSG)
resource "azurerm_subnet_network_security_group_association" "lab06csub01" {
  subnet_id                 = azurerm_subnet.lab06csub01.id
  network_security_group_id = azurerm_network_security_group.lab06c.id
}

# App Gateway dedicated NSG for frontend subnet
resource "azurerm_network_security_group" "lab06cagw" {
  name                = "${local.lab06c_name}-agw-nsg-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_network_security_rule" "lab06cagw_http" {
  name                        = "AllowHTTP"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "*"
  destination_port_range      = "80"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab06cagw.name
}

resource "azurerm_network_security_rule" "lab06cagw_https" {
  name                        = "AllowHTTPS"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "*"
  destination_port_range      = "443"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab06cagw.name
}

resource "azurerm_network_security_rule" "lab06cagw_gwmgr" {
  name                        = "AllowGatewayManager"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "GatewayManager"
  destination_port_range      = "65200-65535"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab06cagw.name
}

resource "azurerm_network_security_rule" "lab06cagw_lb" {
  name                        = "AllowAzureLoadBalancer"
  priority                    = 140
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_port_range      = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab06cagw.name
}

resource "azurerm_subnet_network_security_group_association" "lab06csub02" {
  subnet_id                 = azurerm_subnet.lab06csub02.id
  network_security_group_id = azurerm_network_security_group.lab06cagw.id
}

resource "azurerm_network_interface" "lab06c01" {
  name                = "${local.lab06c_name}-vm-01-nic-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab06c_name}-vm-01-ipconfig-${local.random_str}"
    subnet_id                     = azurerm_subnet.lab06csub01.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = local.default_tags
}

resource "azurerm_network_interface_security_group_association" "lab06c01" {
  network_interface_id      = azurerm_network_interface.lab06c01.id
  network_security_group_id = azurerm_network_security_group.lab06c.id
}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "lab06c01" {
  network_interface_id    = azurerm_network_interface.lab06c01.id
  ip_configuration_name   = azurerm_network_interface.lab06c01.ip_configuration[0].name
  backend_address_pool_id = "${azurerm_application_gateway.lab06c.id}/backendAddressPools/${local.lab06c_bepool_name}"
}

resource "azurerm_windows_virtual_machine" "lab06c01" {
  name                  = "${local.lab06c_name}-vm01-${local.random_str}"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab06c01.id]
  size                  = local.vm_size

  os_disk {
    name                 = "${local.lab06c_name}-vm-01-osdisk-${local.random_str}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab06c_name}-vm01-${local.random_str}"
  admin_username = local.user_name
  admin_password = local.user_password

  identity {
    type = "SystemAssigned"
  }

  tags = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab06c01ama" {
  name                       = "AzureMonitorWindowsAgent"
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06c01.id
  tags                       = local.default_tags
}

resource "azurerm_monitor_data_collection_rule_association" "lab06c01" {
  name                    = "lab06c01-dcra"
  target_resource_id      = azurerm_windows_virtual_machine.lab06c01.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vminsights.id
  description             = "VM Insights DCR association for lab06c01"
}

resource "azurerm_monitor_data_collection_rule_association" "lab06c01_otel" {
  name                    = "lab06c01-otel-dcra"
  target_resource_id      = azurerm_windows_virtual_machine.lab06c01.id
  data_collection_rule_id = azapi_resource.vminsights_otel.id
  description             = "OpenTelemetry metrics DCR association for lab06c01"
}

resource "azurerm_virtual_machine_extension" "lab06c01script" {
  name                       = "${local.lab06c_name}-vm-01-script-${local.random_str}"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06c01.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS
  tags     = local.default_tags
}

resource "azurerm_network_interface" "lab06c02" {
  name                = "${local.lab06c_name}-vm-02-nic-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab06c_name}-vm-02-ipconfig-${local.random_str}"
    subnet_id                     = azurerm_subnet.lab06csub01.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = local.default_tags
}

resource "azurerm_network_interface_security_group_association" "lab06c02" {
  network_interface_id      = azurerm_network_interface.lab06c02.id
  network_security_group_id = azurerm_network_security_group.lab06c.id
}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "lab06c02" {
  network_interface_id    = azurerm_network_interface.lab06c02.id
  ip_configuration_name   = azurerm_network_interface.lab06c02.ip_configuration[0].name
  backend_address_pool_id = "${azurerm_application_gateway.lab06c.id}/backendAddressPools/${local.lab06c_bepool_name}"
}

resource "azurerm_windows_virtual_machine" "lab06c02" {
  name                  = "${local.lab06c_name}-vm02-${local.random_str}"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab06c02.id]
  size                  = local.vm_size

  os_disk {
    name                 = "${local.lab06c_name}-vm-02-osdisk-${local.random_str}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab06c_name}-vm02-${local.random_str}"
  admin_username = local.user_name
  admin_password = local.user_password

  identity {
    type = "SystemAssigned"
  }

  tags = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab06c02ama" {
  name                       = "AzureMonitorWindowsAgent"
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06c02.id
  tags                       = local.default_tags
}

resource "azurerm_monitor_data_collection_rule_association" "lab06c02" {
  name                    = "lab06c02-dcra"
  target_resource_id      = azurerm_windows_virtual_machine.lab06c02.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vminsights.id
  description             = "VM Insights DCR association for lab06c02"
}

resource "azurerm_monitor_data_collection_rule_association" "lab06c02_otel" {
  name                    = "lab06c02-otel-dcra"
  target_resource_id      = azurerm_windows_virtual_machine.lab06c02.id
  data_collection_rule_id = azapi_resource.vminsights_otel.id
  description             = "OpenTelemetry metrics DCR association for lab06c02"
}

resource "azurerm_virtual_machine_extension" "lab06c02script" {
  name                       = "${local.lab06c_name}-vm-02-script-${local.random_str}"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06c02.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS
  tags     = local.default_tags
}

resource "azurerm_network_interface" "lab06c03" {
  name                = "${local.lab06c_name}-vm-03-nic-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab06c_name}-vm-03-ipconfig-${local.random_str}"
    subnet_id                     = azurerm_subnet.lab06csub01.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = local.default_tags
}

resource "azurerm_network_interface_security_group_association" "lab06c03" {
  network_interface_id      = azurerm_network_interface.lab06c03.id
  network_security_group_id = azurerm_network_security_group.lab06c.id
}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "lab06c03" {
  network_interface_id    = azurerm_network_interface.lab06c03.id
  ip_configuration_name   = azurerm_network_interface.lab06c03.ip_configuration[0].name
  backend_address_pool_id = "${azurerm_application_gateway.lab06c.id}/backendAddressPools/${local.lab06c_images_bepool_name}"
}

resource "azurerm_windows_virtual_machine" "lab06c03" {
  name                  = "${local.lab06c_name}-vm03-${local.random_str}"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab06c03.id]
  size                  = local.lab06c_small_vm_size

  os_disk {
    name                 = "${local.lab06c_name}-vm-03-osdisk-${local.random_str}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  computer_name  = "lab06c-vm03-cat"
  admin_username = local.user_name
  admin_password = local.user_password

  identity {
    type = "SystemAssigned"
  }

  tags = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab06c03ama" {
  name                       = "AzureMonitorWindowsAgent"
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06c03.id
  tags                       = local.default_tags
}

resource "azurerm_monitor_data_collection_rule_association" "lab06c03" {
  name                    = "lab06c03-dcra"
  target_resource_id      = azurerm_windows_virtual_machine.lab06c03.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vminsights.id
  description             = "VM Insights DCR association for lab06c03"
}

resource "azurerm_monitor_data_collection_rule_association" "lab06c03_otel" {
  name                    = "lab06c03-otel-dcra"
  target_resource_id      = azurerm_windows_virtual_machine.lab06c03.id
  data_collection_rule_id = azapi_resource.vminsights_otel.id
  description             = "OpenTelemetry metrics DCR association for lab06c03"
}

resource "azurerm_virtual_machine_extension" "lab06c03script" {
  name                       = "${local.lab06c_name}-vm-03-script-${local.random_str}"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06c03.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe New-Item -ItemType Directory -Force -Path 'C:\\inetpub\\wwwroot\\images' && powershell.exe Set-Content -Path 'C:\\inetpub\\wwwroot\\images\\index.htm' -Value $('Hello from ' + $env:computername + '. This file is under wwwroot\\images.')"
    }
  SETTINGS
  tags     = local.default_tags
}

resource "azurerm_network_interface" "lab06c04" {
  name                = "${local.lab06c_name}-vm-04-nic-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab06c_name}-vm-04-ipconfig-${local.random_str}"
    subnet_id                     = azurerm_subnet.lab06csub01.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = local.default_tags
}

resource "azurerm_network_interface_security_group_association" "lab06c04" {
  network_interface_id      = azurerm_network_interface.lab06c04.id
  network_security_group_id = azurerm_network_security_group.lab06c.id
}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "lab06c04" {
  network_interface_id    = azurerm_network_interface.lab06c04.id
  ip_configuration_name   = azurerm_network_interface.lab06c04.ip_configuration[0].name
  backend_address_pool_id = "${azurerm_application_gateway.lab06c.id}/backendAddressPools/${local.lab06c_video_bepool_name}"
}

resource "azurerm_windows_virtual_machine" "lab06c04" {
  name                  = "${local.lab06c_name}-vm04-${local.random_str}"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab06c04.id]
  size                  = local.lab06c_small_vm_size

  os_disk {
    name                 = "${local.lab06c_name}-vm-04-osdisk-${local.random_str}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  computer_name  = "lab06c-vm04-cat"
  admin_username = local.user_name
  admin_password = local.user_password

  identity {
    type = "SystemAssigned"
  }

  tags = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab06c04ama" {
  name                       = "AzureMonitorWindowsAgent"
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06c04.id
  tags                       = local.default_tags
}

resource "azurerm_monitor_data_collection_rule_association" "lab06c04" {
  name                    = "lab06c04-dcra"
  target_resource_id      = azurerm_windows_virtual_machine.lab06c04.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vminsights.id
  description             = "VM Insights DCR association for lab06c04"
}

resource "azurerm_monitor_data_collection_rule_association" "lab06c04_otel" {
  name                    = "lab06c04-otel-dcra"
  target_resource_id      = azurerm_windows_virtual_machine.lab06c04.id
  data_collection_rule_id = azapi_resource.vminsights_otel.id
  description             = "OpenTelemetry metrics DCR association for lab06c04"
}

resource "azurerm_virtual_machine_extension" "lab06c04script" {
  name                       = "${local.lab06c_name}-vm-04-script-${local.random_str}"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06c04.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe Set-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello from ' + $env:computername + '. This file is under the wwwroot root.')"
    }
  SETTINGS
  tags     = local.default_tags
}

resource "azurerm_monitor_diagnostic_setting" "lab06c_appgw" {
  name                       = "lab06c-appgw-diag"
  target_resource_id         = azurerm_application_gateway.lab06c.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab06c_nsg" {
  name                       = "lab06c-nsg-diag"
  target_resource_id         = azurerm_network_security_group.lab06c.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab06cagw_nsg" {
  name                       = "lab06cagw-nsg-diag"
  target_resource_id         = azurerm_network_security_group.lab06cagw.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab06c_pip" {
  name                       = "lab06c-pip-diag"
  target_resource_id         = azurerm_public_ip.lab06c.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab06c_vnet" {
  name                       = "lab06c-vnet-diag"
  target_resource_id         = azurerm_virtual_network.lab06c.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_metric {
    category = "AllMetrics"
  }
}

output "lab06c_application_gateway_fqdn" {
  description = "Fully qualified domain name of the lab 06C Application Gateway."
  value       = azurerm_public_ip.lab06c.fqdn
}

output "lab06c_root_url" {
  description = "Root URL routed to the default backend pool."
  value       = "http://${azurerm_public_ip.lab06c.fqdn}/"
}

output "lab06c_images_url" {
  description = "Images URL routed to the images backend pool."
  value       = "http://${azurerm_public_ip.lab06c.fqdn}/images/"
}

output "lab06c_video_url" {
  description = "Video URL routed to the video backend pool."
  value       = "http://${azurerm_public_ip.lab06c.fqdn}/video/"
}

output "lab06c_legacy_url" {
  description = "Legacy URL redirected to the existing HTTP listener."
  value       = "http://${azurerm_public_ip.lab06c.fqdn}/legacy/"
}
