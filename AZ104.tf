provider "azurerm" {
  # The "feature" block is required for AzureRM provider 2.x. 
  # If you are using version 1.x, the "features" block is not allowed.
  version = "~>2.0"
  features {}
}

locals {
  group_name               = "AZ10402"
  lab01_name               = "lab01"
  lab02_name               = "lab02"
  lab03_name               = "lab03"
  lab04_name               = "lab04"
  lab05a_name              = "lab05a"
  lab05b_name              = "lab05b"
  lab06a_name              = "lab06a"
  lab06b_name              = "lab06b"
  lab06c_name              = "lab06c"
  lab07_name               = "lab07"
  lab08_name               = "lab08"
  lab10_name               = "lab10"
  lab11_name               = "lab11"
  lab09a_name              = "lab09a"
  lab09b_name              = "lab09b"
  lab09c_name              = "lab09c"
  lab09d_name              = "lab09d"
  lab01_name_with_postfix  = lower("${local.lab01_name}${random_string.rid.result}")
  lab02_name_with_postfix  = lower("${local.lab02_name}${random_string.rid.result}")
  lab03_name_with_postfix  = lower("${local.lab03_name}${random_string.rid.result}")
  lab04_name_with_postfix  = lower("${local.lab04_name}${random_string.rid.result}")
  lab05a_name_with_postfix = lower("${local.lab05a_name}${random_string.rid.result}")
  lab05b_name_with_postfix = lower("${local.lab05b_name}${random_string.rid.result}")
  lab06a_name_with_postfix = lower("${local.lab06a_name}${random_string.rid.result}")
  lab06b_name_with_postfix = lower("${local.lab06b_name}${random_string.rid.result}")
  lab06c_name_with_postfix = lower("${local.lab06c_name}${random_string.rid.result}")
  lab07_name_with_postfix  = lower("${local.lab07_name}${random_string.rid.result}")
  lab08_name_with_postfix  = lower("${local.lab08_name}${random_string.rid.result}")
  lab10_name_with_postfix  = lower("${local.lab10_name}${random_string.rid.result}")
  lab11_name_with_postfix  = lower("${local.lab11_name}${random_string.rid.result}")
  lab09a_name_with_postfix = lower("${local.lab09a_name}${random_string.rid.result}")
  lab09b_name_with_postfix = lower("${local.lab09b_name}${random_string.rid.result}")
  lab09c_name_with_postfix = lower("${local.lab09c_name}${random_string.rid.result}")
  lab09d_name_with_postfix = lower("${local.lab09d_name}${random_string.rid.result}")
  user_name                = "demouser"
  user_passowrd            = "Azuredemo2020"
  vm_size                  = "Standard_D4s_v4"
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

data "azurerm_client_config" "current" {}

resource "random_string" "rid" {
  length  = 3
  special = false
  number  = false
}

resource "random_integer" "rint" {
  min = 100
  max = 999
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "az104" {
  name     = local.group_name
  location = "southeastasia"

  tags = {
    environment = local.group_name
  }
}

## LAB-04-VNET
resource "azurerm_virtual_network" "lab04" {
  name                = local.lab04_name_with_postfix
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
}

resource "azurerm_network_security_group" "lab04" {
  name                = local.lab04_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
}

resource "azurerm_network_security_rule" "lab04" {
  name                        = "RDP"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "3389"
  destination_port_range      = "3389"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab04.name
}

resource "azurerm_subnet" "lab04" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab04.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_subnet" "lab04firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab04.name
  address_prefixes     = ["10.10.2.0/24"]
}

resource "azurerm_public_ip" "lab04firewall" {
  name                = "${local.lab04_name_with_postfix}firewall"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "lab04" {
  name                = local.lab04_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.lab04firewall.id
    public_ip_address_id = azurerm_public_ip.lab04firewall.id
  }
}

resource "azurerm_firewall_application_rule_collection" "lab04" {
  name                = "App-Coll01"
  azure_firewall_name = azurerm_firewall.lab04.name
  resource_group_name = azurerm_resource_group.az104.name
  priority            = 200
  action              = "Allow"

  rule {
    name = "Allow-Google"

    source_addresses = [
      "10.10.1.0/24",
    ]

    target_fqdns = [
      "*.google.com",
    ]

    protocol {
      port = "443"
      type = "Https"
    }

    protocol {
      port = "80"
      type = "Http"
    }
  }
}

resource "azurerm_firewall_network_rule_collection" "lab04" {
  name                = "Net-Coll01"
  azure_firewall_name = azurerm_firewall.lab04.name
  resource_group_name = azurerm_resource_group.az104.name
  priority            = 200
  action              = "Allow"

  rule {
    name = "Allow-DNS"

    source_addresses = [
      "10.10.1.0/24",
    ]

    destination_ports = [
      "53",
    ]

    destination_addresses = [
      "8.8.8.8",
      "8.8.4.4",
    ]

    protocols = [
      "TCP",
      "UDP",
    ]
  }
}

resource "azurerm_firewall_nat_rule_collection" "lab04" {
  name                = "rdp"
  azure_firewall_name = azurerm_firewall.lab04.name
  resource_group_name = azurerm_resource_group.az104.name
  priority            = 200
  action              = "Dnat"

  rule {
    name = "rdp-nat"

    source_addresses = [
      "*",
    ]

    destination_ports = [
      "3389",
    ]

    destination_addresses = [
      azurerm_public_ip.lab04firewall.ip_address
    ]

    translated_port = 3389

    translated_address = azurerm_network_interface.lab04.private_ip_address

    protocols = [
      "TCP",
      "UDP",
    ]
  }
}

resource "azurerm_route_table" "lab04" {
  name                          = local.lab04_name_with_postfix
  location                      = azurerm_resource_group.az104.location
  resource_group_name           = azurerm_resource_group.az104.name
  disable_bgp_route_propagation = true

  route {
    name                   = "fw-dg"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_public_ip.lab04firewall.ip_address
  }
}

resource "azurerm_dns_zone" "lab04" {
  name                = "${local.lab04_name_with_postfix}public.com"
  resource_group_name = azurerm_resource_group.az104.name
}

resource "azurerm_private_dns_zone" "lab04" {
  name                = "${local.lab04_name_with_postfix}private.com"
  resource_group_name = azurerm_resource_group.az104.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "lab04" {
  name                  = local.lab04_name_with_postfix
  resource_group_name   = azurerm_resource_group.az104.name
  private_dns_zone_name = azurerm_private_dns_zone.lab04.name
  virtual_network_id    = azurerm_virtual_network.lab04.id
  registration_enabled  = true
}

resource "azurerm_network_interface" "lab04" {
  name                = local.lab04_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  dns_servers         = ["8.8.8.8", "8.8.4.4"]

  ip_configuration {
    name                          = local.lab04_name_with_postfix
    subnet_id                     = azurerm_subnet.lab04.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_windows_virtual_machine" "lab04" {
  name                  = local.lab04_name_with_postfix
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab04.id]
  size                  = local.vm_size

  os_disk {
    name                 = local.lab04_name_with_postfix
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  computer_name  = local.lab04_name
  admin_username = local.user_name
  admin_password = local.user_passowrd

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_machine_extension" "lab04aad" {
  name                       = "${local.lab04_name_with_postfix}aad"
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab04.id

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_machine_extension" "lab04script" {
  name                       = "${local.lab04_name_with_postfix}script"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.9"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab04.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS

  tags = {
    environment = local.group_name
  }
}

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

resource "azurerm_virtual_machine_extension" "lab05a01aad" {
  name                       = "${local.lab05a_name_with_postfix}01aad"
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05a01.id

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

resource "azurerm_virtual_machine_extension" "lab05a02aad" {
  name                       = "${local.lab05a_name_with_postfix}02aad"
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05a02.id

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

resource "azurerm_virtual_machine_extension" "lab05a03aad" {
  name                       = "${local.lab05a_name_with_postfix}03aad"
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05a03.id

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

# LAB-05-B-VPN
resource "azurerm_virtual_network" "lab05b" {
  name                = local.lab05b_name_with_postfix
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_subnet" "lab05b" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab05b.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_subnet" "lab05bgateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab05b.name
  address_prefixes     = ["10.1.2.0/24"]
}

resource "azurerm_public_ip" "lab05b" {
  name                = local.lab05b_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  allocation_method = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "lab05b" {
  name                = local.lab05b_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = "VpnGw3"

  ip_configuration {
    name                          = local.lab05b_name_with_postfix
    public_ip_address_id          = azurerm_public_ip.lab05b.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.lab05bgateway.id
  }

  vpn_client_configuration {
    address_space = ["10.2.1.0/24"]

    root_certificate {
      name = "P2SRootCert"

      public_cert_data = <<EOF
MIIC5zCCAc+gAwIBAgIQEZYqUqQMnL9FuXz7i/GTtzANBgkqhkiG9w0BAQsFADAW
MRQwEgYDVQQDDAtQMlNSb290Q2VydDAeFw0yMDA5MjMwNTA5MTBaFw0yMTA5MjMw
NTI5MTBaMBYxFDASBgNVBAMMC1AyU1Jvb3RDZXJ0MIIBIjANBgkqhkiG9w0BAQEF
AAOCAQ8AMIIBCgKCAQEA319ve5/ejhgKdM4KsezjfUcBKFODCesVlNTJuOsmC7qP
yurQMOkxug308TSu+ED0D1+sjRcGH4OJvj7/A1nAJcbooGxJogTrbLoFfxpLaNmq
toNYnGBJYa1sCrYLNXXQTB3FEj6EDOLGm6xLod91bs8blJ72w1hq6hg11IK4S/lp
6JB43fjY89tUNG5WYjONYbOWhcRgxdSNEtXmWvbiGLWRmnjgnBez0oqKZV68IcfZ
V+wyXGNpWtn6zcMBWj9hPZ76hTXGQxK69fSY2WSNZpTJjBqrYspxWs7J7Tw06+EX
giKbQYN5zunkJtf1hzwwMsWV1BDDDrJ8cktB0OJ6dQIDAQABozEwLzAOBgNVHQ8B
Af8EBAMCAgQwHQYDVR0OBBYEFEDJwRO2HYRJ0l/+XJG20rPUtV2cMA0GCSqGSIb3
DQEBCwUAA4IBAQCYXV+hw1a/1ertBbComRAZL0xzwO6EAOYLDt7g3AA9xiLEQIyD
KNtDp+cl6uLaZ/iRpDHmgYpNm/SLzkJH6mU9inF33eyAG+NVRPdhYwVYn4Isuk5M
JzVivOnBQFs3sEHarK1x8ygeFmgUGbUsroS4tnGPJKGzvh8b4NrWA9N+6iD7RzHU
mLREFeWhEzDiN/R4VPuDgK1oV+WNXwpHxxmWFHFZgX85PNzYmTCXGFOPWp+vwbj9
eVk8KtemwHFZ9Gi0ScbmlmM8uGPkJSjyXE8ruqdI7t/IDjjYAxxJ09ykk8YRCKTe
p6At18EU+qgxgdgmCB+HGh8c247Z1cURBfeL
EOF

    }
  }
}

resource "azurerm_local_network_gateway" "lab05b" {
  name                = local.lab05b_name_with_postfix
  resource_group_name = azurerm_resource_group.az104.name
  location            = azurerm_resource_group.az104.location
  gateway_address     = "114.32.33.212"
  address_space       = ["192.168.112.0/24"]
}

resource "azurerm_network_security_group" "lab05b" {
  name                = local.lab05b_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_security_rule" "lab05b" {
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
  network_security_group_name = azurerm_network_security_group.lab05b.name
}

resource "azurerm_network_interface" "lab05b" {
  name                = local.lab05b_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = local.lab05b_name_with_postfix
    subnet_id                     = azurerm_subnet.lab05b.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_interface_security_group_association" "lab05b" {
  network_interface_id      = azurerm_network_interface.lab05b.id
  network_security_group_id = azurerm_network_security_group.lab05b.id
}

resource "azurerm_windows_virtual_machine" "lab05b" {
  name                  = local.lab05b_name_with_postfix
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab05b.id]
  size                  = local.vm_size

  os_disk {
    name                 = local.lab05b_name_with_postfix
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  computer_name  = local.lab05b_name
  admin_username = local.user_name
  admin_password = local.user_passowrd

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_machine_extension" "lab05baad" {
  name                       = "${local.lab05a_name_with_postfix}03aad"
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05b.id

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_machine_extension" "lab05bscript" {
  name                       = "${local.lab05a_name_with_postfix}03script"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.9"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05b.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS

  tags = {
    environment = local.group_name
  }
}

## LAB-06-A-ROUTE-TABLE
resource "azurerm_route_table" "lab06a" {
  name                          = local.lab06a_name_with_postfix
  location                      = azurerm_resource_group.az104.location
  resource_group_name           = azurerm_resource_group.az104.name
  disable_bgp_route_propagation = false

  route {
    name           = "route1"
    address_prefix = "10.0.0.0/16"
    next_hop_type  = "vnetlocal"
  }
}

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
  address_prefix       = "10.10.1.0/24"
}

resource "azurerm_public_ip" "lab06b" {
  name                = local.lab06b_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  allocation_method   = "Static"
  sku                 = "Standard"
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

resource "azurerm_virtual_machine_extension" "lab06b01aad" {
  name                       = "${local.lab06b_name_with_postfix}01aad"
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06b01.id

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

resource "azurerm_virtual_machine_extension" "lab06b02aad" {
  name                       = "${local.lab06b_name_with_postfix}02aad"
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06b02.id

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

resource "azurerm_network_interface" "lab06b03" {
  name                = "${local.lab06b_name_with_postfix}03"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab06b_name_with_postfix}03"
    subnet_id                     = azurerm_subnet.lab06b.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "lab06b03" {
  network_interface_id    = azurerm_network_interface.lab06b03.id
  ip_configuration_name   = "${local.lab06b_name_with_postfix}03"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lab06b.id
}

resource "azurerm_windows_virtual_machine" "lab06b03" {
  name                  = "${local.lab06b_name_with_postfix}03"
  location              = "eastasia"
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab06b03.id]
  size                  = local.vm_size

  os_disk {
    name                 = "${local.lab06b_name_with_postfix}03"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab06b_name}03"
  admin_username = local.user_name
  admin_password = local.user_passowrd

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_machine_extension" "lab06b03aad" {
  name                       = "${local.lab06b_name_with_postfix}03aad"
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06b03.id

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_machine_extension" "lab06b03script" {
  name                       = "${local.lab06b_name_with_postfix}03script"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.9"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab06b03.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS

  tags = {
    environment = local.group_name
  }
}

## LAB-07-STORAGE
resource "azurerm_storage_account" "lab07" {
  name                     = local.lab07_name_with_postfix
  resource_group_name      = azurerm_resource_group.az104.name
  location                 = azurerm_resource_group.az104.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  allow_blob_public_access = true

  tags = {
    environment = local.group_name
  }
}

## LAB-09-A-WEBAPP
resource "azurerm_app_service_plan" "lab09a" {
  name                = local.lab09a_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_app_service" "lab09a" {
  name                = local.lab09a_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  app_service_plan_id = azurerm_app_service_plan.lab09a.id

  site_config {
    linux_fx_version = "DOTNETCORE|3.1"
  }
}

resource "azurerm_application_insights" "lab09a" {
  name                = local.lab09a_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  application_type    = "web"

  tags = {
    environment = local.group_name
  }
}

## LAB-9-B-ACI
# Create Container Instance
resource "azurerm_container_group" "lab09b" {
  name                = local.lab09b_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  ip_address_type     = "public"
  dns_name_label      = local.lab09b_name_with_postfix
  os_type             = "Linux"

  container {
    name   = "hello-world"
    image  = "microsoft/aci-helloworld:latest"
    cpu    = "2"
    memory = "4"

    ports {
      port     = 80
      protocol = "TCP"
    }
  }

  tags = {
    environment = local.group_name
  }
}

## LAB-9-C-AKS
resource "azurerm_kubernetes_cluster" "lab09c" {
  name                = local.lab09c_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  dns_prefix          = local.lab09c_name

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  addon_profile {
    aci_connector_linux {
      enabled = false
    }

    azure_policy {
      enabled = false
    }

    http_application_routing {
      enabled = false
    }

    kube_dashboard {
      enabled = true
    }

    oms_agent {
      enabled = false
    }
  }
}

## LAB-10-BACKUP
resource "azurerm_recovery_services_vault" "lab10" {
  name                = local.lab10_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  sku                 = "Standard"

  soft_delete_enabled = false
}

## LAB-11-ALERT
# Create virtual network
resource "azurerm_virtual_network" "lab11" {
  name                = local.lab11_name_with_postfix
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  tags = {
    environment = local.group_name
  }
}

# Create subnet
resource "azurerm_subnet" "lab11" {
  name                 = local.lab11_name_with_postfix
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab11.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "lab11" {
  name                = local.lab11_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  allocation_method   = "Dynamic"
  domain_name_label   = lower(local.lab11_name_with_postfix)

  tags = {
    environment = local.group_name
  }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "lab11" {
  name                = local.lab11_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_security_rule" "lab1101" {
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
  network_security_group_name = azurerm_network_security_group.lab11.name
}

resource "azurerm_network_security_rule" "lab1102" {
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
  network_security_group_name = azurerm_network_security_group.lab11.name
}

# Create network interface
resource "azurerm_network_interface" "lab11" {
  name                = local.lab11_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = local.lab11_name_with_postfix
    subnet_id                     = azurerm_subnet.lab11.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.lab11.id
  }

  tags = {
    environment = local.group_name
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "lab11" {
  network_interface_id      = azurerm_network_interface.lab11.id
  network_security_group_id = azurerm_network_security_group.lab11.id
}

# Create virtual machine
resource "azurerm_windows_virtual_machine" "lab11" {
  name                  = local.lab11_name_with_postfix
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab11.id]
  size                  = local.vm_size

  os_disk {
    name                 = local.lab11_name_with_postfix
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  computer_name  = local.lab11_name
  admin_username = local.user_name
  admin_password = local.user_passowrd

  tags = {
    environment = local.group_name
  }
}
