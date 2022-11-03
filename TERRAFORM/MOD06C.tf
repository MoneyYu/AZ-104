## LAB-06-B-LOAD-BALANCER
resource "azurerm_virtual_network" "lab06c" {
  name                = local.lab06c_name_with_postfix
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
}

resource "azurerm_subnet" "lab06csub01" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab06c.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_subnet" "lab06csub02" {
  name                 = "appgw"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab06c.name
  address_prefixes     = ["10.10.2.0/24"]
}

resource "azurerm_public_ip" "lab06c" {
  name                = local.lab06c_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = local.lab06c_name_with_postfix
}

resource "azurerm_application_gateway" "lab06c" {
  name                = local.lab06c_name_with_postfix
  resource_group_name = azurerm_resource_group.az104.name
  location            = azurerm_resource_group.az104.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "${lab06c_name}-appgw-ipconfig-${random_str}"
    subnet_id = azurerm_subnet.lab06csub02.id
  }

  frontend_port {
    name = "${lab06c_name}-appgw-port-${random_str}"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "${lab06c_name}-appgw-pip-config-${random_str}"
    public_ip_address_id = azurerm_public_ip.lab06c.id
  }

  backend_address_pool {
    name = "${lab06c_name}-appgw-bepool-${random_str}"
    ip_addresses = [
      azurerm_network_interface.lab06c01.private_ip_address,
      azurerm_network_interface.lab06c02.private_ip_address
    ]
  }

  backend_http_settings {
    name                  = "${lab06c_name}-appgw-http-setting-${random_str}"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = "${lab06c_name}-appgw-listener-${random_str}"
    frontend_ip_configuration_name = "${lab06c_name}-appgw-pip-config-${random_str}"
    frontend_port_name             = "${lab06c_name}-appgw-port-${random_str}"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "${lab06c_name}-appgw-rule-${random_str}"
    rule_type                  = "Basic"
    http_listener_name         = "${lab06c_name}-appgw-listener-${random_str}"
    backend_address_pool_name  = "${lab06c_name}-appgw-bepool-${random_str}"
    backend_http_settings_name = "${lab06c_name}-appgw-http-setting-${random_str}"
  }
}

resource "azurerm_network_security_group" "lab06c" {
  name                = local.lab06c_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_security_rule" "lab06c" {
  name                        = "HTTP"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "*"
  destination_port_range      = "80"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab06c.name
}

resource "azurerm_network_interface" "lab06c01" {
  name                = "${local.lab06c_name_with_postfix}01"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab06c_name_with_postfix}01"
    subnet_id                     = azurerm_subnet.lab06c.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_interface_security_group_association" "lab06c01" {
  network_interface_id      = azurerm_network_interface.lab06c01.id
  network_security_group_id = azurerm_network_security_group.lab06c.id
}

resource "azurerm_network_interface_backend_address_pool_association" "lab06c01" {
  network_interface_id    = azurerm_network_interface.lab06c01.id
  ip_configuration_name   = "${local.lab06c_name_with_postfix}01"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lab06c.id
}

resource "azurerm_windows_virtual_machine" "lab06c01" {
  name                  = "${local.lab06c_name_with_postfix}01"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab06c01.id]
  size                  = local.vm_size

  os_disk {
    name                 = "${local.lab06c_name_with_postfix}01"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab06c_name}01"
  admin_username = local.user_name
  admin_password = local.user_passowrd

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_machine_extension" "lab06c01script" {
  name                       = "${local.lab06c_name_with_postfix}01script"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.9"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06c01.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_interface" "lab06c02" {
  name                = "${local.lab06c_name_with_postfix}02"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab06c_name_with_postfix}02"
    subnet_id                     = azurerm_subnet.lab06c.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_interface_security_group_association" "lab06c02" {
  network_interface_id      = azurerm_network_interface.lab06c02.id
  network_security_group_id = azurerm_network_security_group.lab06c.id
}

resource "azurerm_network_interface_backend_address_pool_association" "lab06c02" {
  network_interface_id    = azurerm_network_interface.lab06c02.id
  ip_configuration_name   = "${local.lab06c_name_with_postfix}02"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lab06c.id
}

resource "azurerm_windows_virtual_machine" "lab06c02" {
  name                  = "${local.lab06c_name_with_postfix}02"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab06c02.id]
  size                  = local.vm_size

  os_disk {
    name                 = "${local.lab06c_name_with_postfix}02"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab06c_name}02"
  admin_username = local.user_name
  admin_password = local.user_passowrd

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_machine_extension" "lab06c02script" {
  name                       = "${local.lab06c_name_with_postfix}02script"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.9"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06c02.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS

  tags = {
    environment = local.group_name
  }
}
