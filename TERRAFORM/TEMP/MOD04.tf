## LAB-04-VNET
resource "azurerm_virtual_network" "lab04" {
  name                = "${local.lab04_name}-vnet-${local.random_str}"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_network_security_group" "lab04" {
  name                = "${local.lab04_name}-nsg-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_network_security_rule" "lab04" {
  name                        = "RDP"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "3389"
  destination_port_range      = "3389"
  source_address_prefix       = chomp(data.http.myip.response_body)
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

resource "azurerm_subnet_network_security_group_association" "lab04" {
  subnet_id                 = azurerm_subnet.lab04.id
  network_security_group_id = azurerm_network_security_group.lab04.id
}

resource "azurerm_subnet" "lab04firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab04.name
  address_prefixes     = ["10.10.2.0/24"]
}

resource "azurerm_public_ip" "lab04" {
  name                = "${local.lab04_name}-pip-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${local.lab04_name}-pip-${local.random_str}"
  tags                = local.default_tags
}

resource "azurerm_firewall" "lab04" {
  name                = "${local.lab04_name}-fw-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  firewall_policy_id = azurerm_firewall_policy.lab04.id

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.lab04firewall.id
    public_ip_address_id = azurerm_public_ip.lab04.id
  }
  tags = local.default_tags
}

resource "azurerm_firewall_policy" "lab04" {
  name                = "${local.lab04_name}-fw-policy-${local.random_str}"
  resource_group_name = azurerm_resource_group.az104.name
  location            = azurerm_resource_group.az104.location
  tags                = local.default_tags
}

resource "azurerm_firewall_policy_rule_collection_group" "lab04" {
  name               = "${local.lab04_name}-fw-policy-group-${local.random_str}"
  firewall_policy_id = azurerm_firewall_policy.lab04.id
  priority           = 500

  application_rule_collection {
    name     = "app_rule_collection1"
    priority = 500
    action   = "Allow"

    rule {
      name              = "Allow-Google-01"
      source_addresses  = ["10.10.1.0/24"]
      destination_fqdns = ["*.google.com"]
      protocols {
        port = 443
        type = "Https"
      }
      protocols {
        port = 80
        type = "Http"
      }
    }

    rule {
      name              = "Allow-Google-02"
      source_addresses  = ["10.10.1.0/24"]
      destination_fqdns = ["google.com"]
      protocols {
        port = 443
        type = "Https"
      }
      protocols {
        port = 80
        type = "Http"
      }
    }

    rule {
      name              = "Allow-Bing"
      source_addresses  = ["10.10.1.0/24"]
      destination_fqdns = ["*.bing.com"]
      protocols {
        port = 443
        type = "Https"
      }
      protocols {
        port = 80
        type = "Http"
      }
    }
  }

  network_rule_collection {
    name     = "network_rule_collection1"
    priority = 400
    action   = "Allow"

    rule {
      name                  = "Allow-DNS"
      source_addresses      = ["10.10.1.0/24"]
      destination_ports     = ["53"]
      destination_addresses = ["8.8.8.8", "8.8.4.4"]
      protocols             = ["TCP", "UDP"]
    }
  }

  nat_rule_collection {
    name     = "nat_rule_collection1"
    priority = 300
    action   = "Dnat"

    rule {
      name                = "RDP-NAT"
      source_addresses    = ["*"]
      destination_ports   = ["3389"]
      destination_address = azurerm_public_ip.lab04.ip_address
      translated_port     = 3389
      translated_address  = azurerm_network_interface.lab04.private_ip_address
      protocols           = ["TCP", "UDP", ]
    }
  }
}

resource "azurerm_route_table" "lab04" {
  name                          = "${local.lab04_name}-routes-${local.random_str}"
  location                      = azurerm_resource_group.az104.location
  resource_group_name           = azurerm_resource_group.az104.name
  bgp_route_propagation_enabled = false
  tags                          = local.default_tags
}

resource "azurerm_route" "lab04_fw_dg" {
  name                   = "fw-dg"
  resource_group_name    = azurerm_resource_group.az104.name
  route_table_name       = azurerm_route_table.lab04.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.lab04.ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "lab04" {
  subnet_id      = azurerm_subnet.lab04.id
  route_table_id = azurerm_route_table.lab04.id
}

resource "azurerm_dns_zone" "lab04" {
  name                = "${local.lab04_name}-public-dns-${local.random_str}.com"
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_private_dns_zone" "lab04" {
  name                = "${local.lab04_name}-private-dns-${local.random_str}.local"
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "lab04" {
  name                  = "${local.lab04_name}-zone-link-${local.random_str}"
  resource_group_name   = azurerm_resource_group.az104.name
  private_dns_zone_name = azurerm_private_dns_zone.lab04.name
  virtual_network_id    = azurerm_virtual_network.lab04.id
  registration_enabled  = true
  tags                  = local.default_tags
}

resource "azurerm_network_interface" "lab04" {
  name                = "${local.lab04_name}-nic-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  dns_servers         = ["8.8.8.8", "8.8.4.4"]

  ip_configuration {
    name                          = "${local.lab04_name}-nic-ipconfig-${local.random_str}"
    subnet_id                     = azurerm_subnet.lab04.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = local.default_tags
}

resource "azurerm_windows_virtual_machine" "lab04" {
  name                  = "${local.lab04_name}-vm-${local.random_str}"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab04.id]
  size                  = local.vm_size

  os_disk {
    name                 = "${local.lab04_name}-osdisk-${local.random_str}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab04_name}-vm-${local.random_str}"
  admin_username = local.user_name
  admin_password = local.user_password

  identity {
    type = "SystemAssigned"
  }

  tags = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab04ama" {
  name                       = "AzureMonitorWindowsAgent"
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab04.id
  tags                       = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab04da" {
  name                       = "DependencyAgentWindows"
  publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                       = "DependencyAgentWindows"
  type_handler_version       = "9.10"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab04.id

  settings = jsonencode({
    enableAMA = "true"
  })

  tags = local.default_tags

  depends_on = [azurerm_virtual_machine_extension.lab04ama]
}

resource "azurerm_monitor_data_collection_rule_association" "lab04" {
  name                    = "lab04-dcra"
  target_resource_id      = azurerm_windows_virtual_machine.lab04.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vminsights.id
  description             = "VM Insights DCR association for lab04"
}

resource "azurerm_virtual_machine_extension" "lab04script" {
  name                       = "${local.lab04_name}-vm-script-${local.random_str}"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab04.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS
  tags     = local.default_tags
}
