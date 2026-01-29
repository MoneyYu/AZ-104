## LAB-8-VM
resource "azurerm_virtual_network" "lab08" {
  name                = "${local.lab08_name}-vnet-${local.random_str}"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_subnet" "lab08" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab08.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_subnet" "lab08bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab08.name
  address_prefixes     = ["10.10.2.0/24"]
}

resource "azurerm_public_ip" "lab08" {
  name                = "${local.lab08_name}-pip-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.default_tags
}

resource "azurerm_bastion_host" "lab08" {
  name                   = "${local.lab08_name}-bastion-${local.random_str}"
  location               = azurerm_resource_group.az104.location
  resource_group_name    = azurerm_resource_group.az104.name
  sku                    = "Standard"
  file_copy_enabled      = true
  ip_connect_enabled     = true
  shareable_link_enabled = false
  tunneling_enabled      = false
  kerberos_enabled       = true

  ip_configuration {
    name                 = "${local.lab08_name}-bastion-ipconfig-${local.random_str}"
    subnet_id            = azurerm_subnet.lab08bastion.id
    public_ip_address_id = azurerm_public_ip.lab08.id
  }
  
  lifecycle {
    ignore_changes = [
      ip_configuration[0].subnet_id
    ]
  }
  
  tags = local.default_tags
}

resource "azurerm_network_interface" "lab08" {
  name                = "${local.lab08_name}-nic-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab08_name}-nic-ipconfig-${local.random_str}"
    subnet_id                     = azurerm_subnet.lab08.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = local.default_tags
}

resource "azurerm_windows_virtual_machine" "lab08" {
  name                  = "${local.lab08_name}-vm-${local.random_str}"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab08.id]
  size                  = local.vm_size

  os_disk {
    name                 = "${local.lab08_name}-osdisk-${local.random_str}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab08_name}-vm-${local.random_str}"
  admin_username = local.user_name
  admin_password = local.user_password
  tags           = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab08aad" {
  name                       = "${local.lab08_name}-aad-${local.random_str}"
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab08.id
  tags                       = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab08script" {
  name                       = "${local.lab08_name}-script-${local.random_str}"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab08.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS
  tags     = local.default_tags
}

# Assign "Virtual Machine Administrator Login" role to current user for Entra ID login
resource "azurerm_role_assignment" "lab08_vm_admin" {
  scope                = azurerm_windows_virtual_machine.lab08.id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Alternative: Assign "Virtual Machine User Login" role for non-admin access
# resource "azurerm_role_assignment" "lab08_vm_user" {
#   scope                = azurerm_windows_virtual_machine.lab08.id
#   role_definition_name = "Virtual Machine User Login"
#   principal_id         = data.azurerm_client_config.current.object_id
# }
