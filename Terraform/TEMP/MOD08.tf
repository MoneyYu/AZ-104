## LAB-8-VM
resource "azurerm_virtual_network" "lab08" {
  name                = local.lab08_name_with_postfix
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
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
  name                = local.lab08_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "lab08" {
  name                = local.lab08_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                 = local.lab08_name_with_postfix
    subnet_id            = azurerm_subnet.lab08bastion.id
    public_ip_address_id = azurerm_public_ip.lab08.id
  }
}

resource "azurerm_network_interface" "lab08" {
  name                = local.lab08_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = local.lab08_name_with_postfix
    subnet_id                     = azurerm_subnet.lab08.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_windows_virtual_machine" "lab08" {
  name                  = local.lab08_name_with_postfix
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab08.id]
  size                  = local.vm_size

  os_disk {
    name                 = local.lab08_name_with_postfix
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  computer_name  = local.lab08_name_with_postfix
  admin_username = local.user_name
  admin_password = local.user_passowrd

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_machine_extension" "lab08aad" {
  name                       = "${local.lab08_name_with_postfix}aad"
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06b02.id

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_machine_extension" "lab08script" {
  name                       = "${local.lab08_name_with_postfix}script"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.9"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab08.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS

  tags = {
    environment = local.group_name
  }
}