## LAB-06-B-LOAD-BALANCER
resource "azurerm_virtual_network" "lab06b" {
  name                = local.lab06b_name_with_postfix
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
}

resource "azurerm_subnet" "lab06b" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab06b.name
  address_prefixes       = ["10.10.1.0/24"]
}

resource "azurerm_public_ip" "lab06b" {
  name                = local.lab06b_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = local.lab06b_name_with_postfix
}

resource "azurerm_lb" "lab06b" {
  name                = local.lab06b_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lab06b.id
  }
}

resource "azurerm_lb_backend_address_pool" "lab06b" {
  resource_group_name = azurerm_resource_group.az104.name
  loadbalancer_id     = azurerm_lb.lab06b.id
  name                = "BackendPool"
}

resource "azurerm_lb_probe" "lab06b" {
  resource_group_name = azurerm_resource_group.az104.name
  loadbalancer_id     = azurerm_lb.lab06b.id
  name                = "probe"
  port                = 80
  interval_in_seconds = 5
}

resource "azurerm_lb_rule" "lab06b" {
  resource_group_name            = azurerm_resource_group.az104.name
  loadbalancer_id                = azurerm_lb.lab06b.id
  name                           = "rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.lab06b.id
  probe_id                       = azurerm_lb_probe.lab06b.id
  disable_outbound_snat          = true
}

resource "azurerm_network_security_group" "lab06b" {
  name                = local.lab06b_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_security_rule" "lab06b" {
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
  network_security_group_name = azurerm_network_security_group.lab06b.name
}

resource "azurerm_network_interface" "lab06b01" {
  name                = "${local.lab06b_name_with_postfix}01"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab06b_name_with_postfix}01"
    subnet_id                     = azurerm_subnet.lab06b.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_interface_security_group_association" "lab06b01" {
  network_interface_id      = azurerm_network_interface.lab06b01.id
  network_security_group_id = azurerm_network_security_group.lab06b.id
}

resource "azurerm_network_interface_backend_address_pool_association" "lab06b01" {
  network_interface_id    = azurerm_network_interface.lab06b01.id
  ip_configuration_name   = "${local.lab06b_name_with_postfix}01"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lab06b.id
}

resource "azurerm_windows_virtual_machine" "lab06b01" {
  name                  = "${local.lab06b_name_with_postfix}01"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab06b01.id]
  size                  = local.vm_size

  os_disk {
    name                 = "${local.lab06b_name_with_postfix}01"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab06b_name}01"
  admin_username = local.user_name
  admin_password = local.user_passowrd

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_machine_extension" "lab06b01script" {
  name                       = "${local.lab06b_name_with_postfix}01script"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.9"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06b01.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_interface" "lab06b02" {
  name                = "${local.lab06b_name_with_postfix}02"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab06b_name_with_postfix}02"
    subnet_id                     = azurerm_subnet.lab06b.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_interface_security_group_association" "lab06b02" {
  network_interface_id      = azurerm_network_interface.lab06b02.id
  network_security_group_id = azurerm_network_security_group.lab06b.id
}

resource "azurerm_network_interface_backend_address_pool_association" "lab06b02" {
  network_interface_id    = azurerm_network_interface.lab06b02.id
  ip_configuration_name   = "${local.lab06b_name_with_postfix}02"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lab06b.id
}

resource "azurerm_windows_virtual_machine" "lab06b02" {
  name                  = "${local.lab06b_name_with_postfix}02"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab06b02.id]
  size                  = local.vm_size

  os_disk {
    name                 = "${local.lab06b_name_with_postfix}02"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab06b_name}02"
  admin_username = local.user_name
  admin_password = local.user_passowrd

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_machine_extension" "lab06b02script" {
  name                       = "${local.lab06b_name_with_postfix}02script"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.9"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06b02.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS

  tags = {
    environment = local.group_name
  }
}