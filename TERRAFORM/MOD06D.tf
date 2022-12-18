## LAB-06-D-VWAN
locals {
  lab06d_loc_01 = "japaneast"
  lab06d_loc_02 = "southeastasia"
  lab06d_loc_03 = "eastasia"
}

resource "azurerm_virtual_network" "lab06d01" {
  name                = "${local.lab06d_name}-vnet01-jpe-${local.random_str}"
  address_space       = ["10.11.1.0/24"]
  location            = local.lab06d_loc_01
  resource_group_name = azurerm_resource_group.az104.name

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_subnet" "lab06d01" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab06d01.name
  address_prefixes     = ["10.11.1.0/27"]
}

resource "azurerm_virtual_network" "lab06d02" {
  name                = "${local.lab06d_name}-vnet02-sea-${local.random_str}"
  address_space       = ["10.12.1.0/24"]
  location            = local.lab06d_loc_02
  resource_group_name = azurerm_resource_group.az104.name

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_subnet" "lab06d02" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab06d02.name
  address_prefixes     = ["10.12.1.0/27"]
}

resource "azurerm_virtual_network" "lab06d03" {
  name                = "${local.lab06d_name}-vnet03-ea-${local.random_str}"
  address_space       = ["10.13.1.0/24"]
  location            = local.lab06d_loc_03
  resource_group_name = azurerm_resource_group.az104.name

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_subnet" "lab06d03" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab06d03.name
  address_prefixes     = ["10.13.1.0/27"]
}

resource "azurerm_virtual_wan" "lab06d" {
  name                = "${local.lab06d_name}-vwan-${local.random_str}"
  resource_group_name = azurerm_resource_group.az104.name
  location            = azurerm_resource_group.az104.location

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_hub" "lab06d01" {
  name                = "${local.lab06d_name}-hub01-jpe-${local.random_str}"
  resource_group_name = azurerm_resource_group.az104.name
  location            = local.lab06d_loc_01
  virtual_wan_id      = azurerm_virtual_wan.lab06d.id
  address_prefix      = "10.11.0.0/24"

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_hub" "lab06d02" {
  name                = "${local.lab06d_name}-hub02-sea-${local.random_str}"
  resource_group_name = azurerm_resource_group.az104.name
  location            = local.lab06d_loc_02
  virtual_wan_id      = azurerm_virtual_wan.lab06d.id
  address_prefix      = "10.12.0.0/24"

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_hub" "lab06d03" {
  name                = "${local.lab06d_name}-hub03-ea-${local.random_str}"
  resource_group_name = azurerm_resource_group.az104.name
  location            = local.lab06d_loc_03
  virtual_wan_id      = azurerm_virtual_wan.lab06d.id
  address_prefix      = "10.13.0.0/24"

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_hub_connection" "lab06d01" {
  name                      = "${local.lab06d_name}-vnet01-conn-jpe-${local.random_str}"
  virtual_hub_id            = azurerm_virtual_hub.lab06d01.id
  remote_virtual_network_id = azurerm_virtual_network.lab06d01.id
}

resource "azurerm_virtual_hub_connection" "lab06d02" {
  name                      = "${local.lab06d_name}-vnet02-conn-sea-${local.random_str}"
  virtual_hub_id            = azurerm_virtual_hub.lab06d02.id
  remote_virtual_network_id = azurerm_virtual_network.lab06d02.id
}

resource "azurerm_virtual_hub_connection" "lab06d03" {
  name                      = "${local.lab06d_name}-vnet03-conn-ea-${local.random_str}"
  virtual_hub_id            = azurerm_virtual_hub.lab06d03.id
  remote_virtual_network_id = azurerm_virtual_network.lab06d03.id
}

resource "azurerm_network_security_group" "lab06d01" {
  name                = "${local.lab06d_name}-nsg01-jpe-${local.random_str}"
  location            = local.lab06d_loc_01
  resource_group_name = azurerm_resource_group.az104.name

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_security_group" "lab06d02" {
  name                = "${local.lab06d_name}-nsg02-sea-${local.random_str}"
  location            = local.lab06d_loc_02
  resource_group_name = azurerm_resource_group.az104.name

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_security_group" "lab06d03" {
  name                = "${local.lab06d_name}-nsg03-ea-${local.random_str}"
  location            = local.lab06d_loc_03
  resource_group_name = azurerm_resource_group.az104.name

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_interface" "lab06d01" {
  name                = "${local.lab06d_name}-nic01-jpe-${local.random_str}"
  location            = local.lab06d_loc_01
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab06d_name}-ipconfig-01-${local.random_str}"
    subnet_id                     = azurerm_subnet.lab06d01.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_interface_security_group_association" "lab06d01" {
  network_interface_id      = azurerm_network_interface.lab06d01.id
  network_security_group_id = azurerm_network_security_group.lab06d01.id
}

resource "azurerm_network_interface" "lab06d02" {
  name                = "${local.lab06d_name}-nic02-sea-${local.random_str}"
  location            = local.lab06d_loc_02
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab06d_name}-ipconfig-02-${local.random_str}"
    subnet_id                     = azurerm_subnet.lab06d02.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_interface_security_group_association" "lab06d02" {
  network_interface_id      = azurerm_network_interface.lab06d02.id
  network_security_group_id = azurerm_network_security_group.lab06d02.id
}

resource "azurerm_network_interface" "lab06d03" {
  name                = "${local.lab06d_name}-nic03-ea-${local.random_str}"
  location            = local.lab06d_loc_03
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab06d_name}-ipconfig-03-${local.random_str}"
    subnet_id                     = azurerm_subnet.lab06d03.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_interface_security_group_association" "lab06d03" {
  network_interface_id      = azurerm_network_interface.lab06d03.id
  network_security_group_id = azurerm_network_security_group.lab06d03.id
}

resource "azurerm_windows_virtual_machine" "lab06d01" {
  name                  = "${local.lab06d_name}-vm01-${local.random_str}"
  location              = local.lab06d_loc_01
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab06d01.id]
  size                  = local.vm_size

  os_disk {
    name                 = "${local.lab06d_name}-osdisk-01-${local.random_str}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab06d_name}-vm01-${local.random_str}"
  admin_username = local.user_name
  admin_password = local.user_passowrd

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_machine_extension" "lab06d01script" {
  name                       = "${local.lab06d_name}-script-01-${local.random_str}"
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.0"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06d01.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_windows_virtual_machine" "lab06d02" {
  name                  = "${local.lab06d_name}-vm02-${local.random_str}"
  location              = local.lab06d_loc_02
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab06d02.id]
  size                  = local.vm_size

  os_disk {
    name                 = "${local.lab06d_name}-osdisk-02-${local.random_str}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab06d_name}-vm02-${local.random_str}"
  admin_username = local.user_name
  admin_password = local.user_passowrd

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_machine_extension" "lab06d02script" {
  name                       = "${local.lab06d_name}-script-02-${local.random_str}"
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.0"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06d02.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_windows_virtual_machine" "lab06d03" {
  name                  = "${local.lab06d_name}-vm03-${local.random_str}"
  location              = local.lab06d_loc_03
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab06d03.id]
  size                  = local.vm_size

  os_disk {
    name                 = "${local.lab06d_name}-osdisk-03-${local.random_str}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab06d_name}-vm03-${local.random_str}"
  admin_username = local.user_name
  admin_password = local.user_passowrd

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_machine_extension" "lab06d03script" {
  name                       = "${local.lab06d_name}-script-03-${local.random_str}"
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.0"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06d03.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS

  tags = {
    environment = local.group_name
  }
}