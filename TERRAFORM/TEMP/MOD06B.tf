## LAB-06-B-LOAD-BALANCER
resource "azurerm_virtual_network" "lab06b" {
  name                = "${local.lab06b_name}-vnet-${local.random_str}"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_subnet" "lab06b" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab06b.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_public_ip" "lab06b" {
  name                = "${local.lab06b_name}-pip-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${local.lab06b_name}-pip-${local.random_str}"
  tags                = local.default_tags
}

resource "azurerm_lb" "lab06b" {
  name                = "${local.lab06b_name}-lb-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lab06b.id
  }
  tags = local.default_tags
}

resource "azurerm_lb_backend_address_pool" "lab06b" {
  loadbalancer_id = azurerm_lb.lab06b.id
  name            = "BackendPool"
}

resource "azurerm_lb_probe" "lab06b" {
  loadbalancer_id     = azurerm_lb.lab06b.id
  name                = "probe"
  port                = 80
  interval_in_seconds = 5
}

resource "azurerm_lb_rule" "lab06b" {
  loadbalancer_id                = azurerm_lb.lab06b.id
  name                           = "rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lab06b.id]
  probe_id                       = azurerm_lb_probe.lab06b.id
  disable_outbound_snat          = true
}

resource "azurerm_network_security_group" "lab06b" {
  name                = "${local.lab06b_name}-nsg-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
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

# Subnet-level NSG association for default subnet (shared with existing NSG)
resource "azurerm_subnet_network_security_group_association" "lab06b" {
  subnet_id                 = azurerm_subnet.lab06b.id
  network_security_group_id = azurerm_network_security_group.lab06b.id
}

resource "azurerm_network_interface" "lab06b01" {
  name                = "${local.lab06b_name}-nic-01-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab06b_name}-nic-ipconfig-01-${local.random_str}"
    subnet_id                     = azurerm_subnet.lab06b.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = local.default_tags
}

resource "azurerm_network_interface_security_group_association" "lab06b01" {
  network_interface_id      = azurerm_network_interface.lab06b01.id
  network_security_group_id = azurerm_network_security_group.lab06b.id
}

resource "azurerm_network_interface_backend_address_pool_association" "lab06b01" {
  network_interface_id    = azurerm_network_interface.lab06b01.id
  ip_configuration_name   = "${local.lab06b_name}-nic-ipconfig-01-${local.random_str}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lab06b.id
}

resource "azurerm_windows_virtual_machine" "lab06b01" {
  name                  = "${local.lab06b_name}-vm01-${local.random_str}"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab06b01.id]
  size                  = local.vm_size

  os_disk {
    name                 = "${local.lab06b_name}-osdisk-01-${local.random_str}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab06b_name}-vm01-${local.random_str}"
  admin_username = local.user_name
  admin_password = local.user_password

  identity {
    type = "SystemAssigned"
  }

  tags = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab06b01ama" {
  name                       = "AzureMonitorWindowsAgent"
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06b01.id
  tags                       = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab06b01da" {
  name                       = "DependencyAgentWindows"
  publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                       = "DependencyAgentWindows"
  type_handler_version       = "9.10"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06b01.id

  settings = jsonencode({
    enableAMA = "true"
  })

  tags = local.default_tags

  depends_on = [azurerm_virtual_machine_extension.lab06b01ama]
}

resource "azurerm_monitor_data_collection_rule_association" "lab06b01" {
  name                    = "lab06b01-dcra"
  target_resource_id      = azurerm_windows_virtual_machine.lab06b01.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vminsights.id
  description             = "VM Insights DCR association for lab06b01"
}

resource "azurerm_virtual_machine_extension" "lab06b01script" {
  name                       = "${local.lab06b_name}-script-01-${local.random_str}"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06b01.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS
  tags     = local.default_tags
}

resource "azurerm_network_interface" "lab06b02" {
  name                = "${local.lab06b_name}-nic-02-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab06b_name}-nic-ipconfig-02-${local.random_str}"
    subnet_id                     = azurerm_subnet.lab06b.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = local.default_tags
}

resource "azurerm_network_interface_security_group_association" "lab06b02" {
  network_interface_id      = azurerm_network_interface.lab06b02.id
  network_security_group_id = azurerm_network_security_group.lab06b.id
}

resource "azurerm_network_interface_backend_address_pool_association" "lab06b02" {
  network_interface_id    = azurerm_network_interface.lab06b02.id
  ip_configuration_name   = "${local.lab06b_name}-nic-ipconfig-02-${local.random_str}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lab06b.id
}

resource "azurerm_windows_virtual_machine" "lab06b02" {
  name                  = "${local.lab06b_name}-vm02-${local.random_str}"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab06b02.id]
  size                  = local.vm_size

  os_disk {
    name                 = "${local.lab06b_name}-osdisk-02-${local.random_str}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab06b_name}-vm02-${local.random_str}"
  admin_username = local.user_name
  admin_password = local.user_password

  identity {
    type = "SystemAssigned"
  }

  tags = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab06b02ama" {
  name                       = "AzureMonitorWindowsAgent"
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06b02.id
  tags                       = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab06b02da" {
  name                       = "DependencyAgentWindows"
  publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                       = "DependencyAgentWindows"
  type_handler_version       = "9.10"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06b02.id

  settings = jsonencode({
    enableAMA = "true"
  })

  tags = local.default_tags

  depends_on = [azurerm_virtual_machine_extension.lab06b02ama]
}

resource "azurerm_monitor_data_collection_rule_association" "lab06b02" {
  name                    = "lab06b02-dcra"
  target_resource_id      = azurerm_windows_virtual_machine.lab06b02.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vminsights.id
  description             = "VM Insights DCR association for lab06b02"
}

resource "azurerm_virtual_machine_extension" "lab06b02script" {
  name                       = "${local.lab06b_name}-script-02-${local.random_str}"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06b02.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS
  tags     = local.default_tags
}
