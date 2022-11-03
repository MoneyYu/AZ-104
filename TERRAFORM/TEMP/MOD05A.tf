## LAB-05-A-PEERING
resource "azurerm_virtual_network" "lab05a01" {
  name                = "${local.lab05a_name_with_postfix}01"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_subnet" "lab05a01" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab05a01.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_public_ip" "lab05a01" {
  name                = "${local.lab05a_name_with_postfix}01"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  allocation_method   = "Dynamic"
  domain_name_label   = "${local.lab05a_name_with_postfix}01"

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_security_group" "lab05a01" {
  name                = "${local.lab05a_name_with_postfix}01"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_security_rule" "lab05a01" {
  name                        = "RDP"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "*"
  destination_port_range      = "3389"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab05a01.name
}

resource "azurerm_network_interface" "lab05a01" {
  name                = "${local.lab05a_name_with_postfix}01"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab05a_name_with_postfix}01"
    subnet_id                     = azurerm_subnet.lab05a01.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.lab05a01.id
  }

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_interface_security_group_association" "lab05a01" {
  network_interface_id      = azurerm_network_interface.lab05a01.id
  network_security_group_id = azurerm_network_security_group.lab05a01.id
}

resource "azurerm_windows_virtual_machine" "lab05a01" {
  name                  = "${local.lab05a_name_with_postfix}01"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab05a01.id]
  size                  = local.vm_size

  os_disk {
    name                 = "${local.lab05a_name_with_postfix}01"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab05a_name}01"
  admin_username = local.user_name
  admin_password = local.user_passowrd

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_machine_extension" "lab05a01script" {
  name                       = "${local.lab05a_name_with_postfix}01script"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.9"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05a01.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_network" "lab05a02" {
  name                = "${local.lab05a_name_with_postfix}02"
  address_space       = ["10.2.0.0/16"]
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_subnet" "lab05a02" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab05a02.name
  address_prefixes     = ["10.2.1.0/24"]
}

resource "azurerm_public_ip" "lab05a02" {
  name                = "${local.lab05a_name_with_postfix}02"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  allocation_method   = "Dynamic"
  domain_name_label   = "${local.lab05a_name_with_postfix}02"

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_security_group" "lab05a02" {
  name                = "${local.lab05a_name_with_postfix}02"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_security_rule" "lab05a02" {
  name                        = "RDP"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "*"
  destination_port_range      = "3389"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab05a02.name
}

resource "azurerm_network_interface" "lab05a02" {
  name                = "${local.lab05a_name_with_postfix}02"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab05a_name_with_postfix}02"
    subnet_id                     = azurerm_subnet.lab05a02.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.lab05a02.id
  }

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_interface_security_group_association" "lab05a02" {
  network_interface_id      = azurerm_network_interface.lab05a02.id
  network_security_group_id = azurerm_network_security_group.lab05a02.id
}

resource "azurerm_windows_virtual_machine" "lab05a02" {
  name                  = "${local.lab05a_name_with_postfix}02"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab05a02.id]
  size                  = local.vm_size

  os_disk {
    name                 = "${local.lab05a_name_with_postfix}02"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab05a_name}02"
  admin_username = local.user_name
  admin_password = local.user_passowrd

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_machine_extension" "lab05a02script" {
  name                       = "${local.lab05a_name_with_postfix}02script"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.9"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05a02.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_network" "lab05a03" {
  name                = "${local.lab05a_name_with_postfix}03"
  address_space       = ["10.3.0.0/16"]
  location            = "eastasia"
  resource_group_name = azurerm_resource_group.az104.name

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_subnet" "lab05a03" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab05a03.name
  address_prefixes     = ["10.3.1.0/24"]
}

resource "azurerm_public_ip" "lab05a03" {
  name                = "${local.lab05a_name_with_postfix}03"
  location            = "eastasia"
  resource_group_name = azurerm_resource_group.az104.name
  allocation_method   = "Dynamic"
  domain_name_label   = "${local.lab05a_name_with_postfix}03"

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_security_group" "lab05a03" {
  name                = "${local.lab05a_name_with_postfix}03"
  location            = "eastasia"
  resource_group_name = azurerm_resource_group.az104.name

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_security_rule" "lab05a03" {
  name                        = "RDP"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "*"
  destination_port_range      = "3389"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab05a03.name
}

resource "azurerm_network_interface" "lab05a03" {
  name                = "${local.lab05a_name_with_postfix}03"
  location            = "eastasia"
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab05a_name_with_postfix}03"
    subnet_id                     = azurerm_subnet.lab05a03.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.lab05a03.id
  }

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_interface_security_group_association" "lab05a03" {
  network_interface_id      = azurerm_network_interface.lab05a03.id
  network_security_group_id = azurerm_network_security_group.lab05a03.id
}

resource "azurerm_windows_virtual_machine" "lab05a03" {
  name                  = "${local.lab05a_name_with_postfix}03"
  location              = "eastasia"
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab05a03.id]
  size                  = local.vm_size

  os_disk {
    name                 = "${local.lab05a_name_with_postfix}03"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab05a_name}03"
  admin_username = local.user_name
  admin_password = local.user_passowrd

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_machine_extension" "lab05a03script" {
  name                       = "${local.lab05a_name_with_postfix}03script"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.9"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05a03.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS

  tags = {
    environment = local.group_name
  }
}