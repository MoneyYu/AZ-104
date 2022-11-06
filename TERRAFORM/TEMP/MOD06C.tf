## LAB-06-B-LOAD-BALANCER
resource "azurerm_virtual_network" "lab06c" {
  name                = "${local.lab06c_name}-vnet-${local.random_str}"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
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
  domain_name_label   = local.lab06c_name_with_postfix
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
    name = "${local.lab06c_name}-appgw-bepool-${local.random_str}"
    ip_addresses = [
      azurerm_network_interface.lab06c01.private_ip_address,
      azurerm_network_interface.lab06c02.private_ip_address
    ]
  }

  backend_http_settings {
    name                  = "${local.lab06c_name}-appgw-http-setting-${local.random_str}"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = "${local.lab06c_name}-appgw-listener-${local.random_str}"
    frontend_ip_configuration_name = "${local.lab06c_name}-appgw-pip-config-${local.random_str}"
    frontend_port_name             = "${local.lab06c_name}-appgw-port-${local.random_str}"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "${local.lab06c_name}-appgw-rule-${local.random_str}"
    rule_type                  = "Basic"
    http_listener_name         = "${local.lab06c_name}-appgw-listener-${local.random_str}"
    backend_address_pool_name  = "${local.lab06c_name}-appgw-bepool-${local.random_str}"
    backend_http_settings_name = "${local.lab06c_name}-appgw-http-setting-${local.random_str}"
  }
}

resource "azurerm_network_security_group" "lab06c" {
  name                = "${local.lab06c_name}-nsg-${local.random_str}"
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
  name                = "${local.lab06c_name}-vm-01-nic-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab06c_name}-vm-01-ipconfig-${local.random_str}"
    subnet_id                     = azurerm_subnet.lab06csub01.id
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
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab06c_name}-vm01-${local.random_str}"
  admin_username = local.user_name
  admin_password = local.user_passowrd

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_machine_extension" "lab06c01script" {
  name                       = "${local.lab06c_name}-vm-01-script-${local.random_str}"
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
  name                = "${local.lab06c_name}-vm-02-nic-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab06c_name}-vm-02-ipconfig-${local.random_str}"
    subnet_id                     = azurerm_subnet.lab06csub01.id
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
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab06c_name}-vm02-${local.random_str}"
  admin_username = local.user_name
  admin_password = local.user_passowrd

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_machine_extension" "lab06c02script" {
  name                       = "${local.lab06c_name}-vm-02-script-${local.random_str}"
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
