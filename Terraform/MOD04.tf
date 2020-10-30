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
      type = "Https"
    }

    protocol {
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
    next_hop_in_ip_address = azurerm_firewall.lab04.ip_configuration[0].private_ip_address 
  }
}

resource "azurerm_subnet_route_table_association" "example" {
  subnet_id      = azurerm_subnet.lab04.id
  route_table_id = azurerm_route_table.lab04.id
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