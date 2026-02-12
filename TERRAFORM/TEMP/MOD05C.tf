## LAB-8-VM
resource "azurerm_virtual_network" "lab05c" {
  name                = "${local.lab05c_name}-vnet-${local.random_str}"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_subnet" "lab05cdefault" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab05c.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_subnet" "lab05cbastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab05c.name
  address_prefixes     = ["10.10.2.0/24"]
}

resource "azurerm_network_security_group" "lab05c" {
  name                = "${local.lab05c_name}-nsg-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_subnet_network_security_group_association" "lab05c" {
  subnet_id                 = azurerm_subnet.lab05cdefault.id
  network_security_group_id = azurerm_network_security_group.lab05c.id
}

# Bastion dedicated NSG with required rules
resource "azurerm_network_security_group" "lab05cbastion" {
  name                = "${local.lab05c_name}-bastion-nsg-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

# Inbound rules for Bastion
resource "azurerm_network_security_rule" "lab05cbastion_inbound_https" {
  name                        = "AllowHttpsInbound"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "Internet"
  destination_port_range      = "443"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab05cbastion.name
}

resource "azurerm_network_security_rule" "lab05cbastion_inbound_gwmgr" {
  name                        = "AllowGatewayManagerInbound"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "GatewayManager"
  destination_port_range      = "443"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab05cbastion.name
}

resource "azurerm_network_security_rule" "lab05cbastion_inbound_lb" {
  name                        = "AllowAzureLoadBalancerInbound"
  priority                    = 140
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_port_range      = "443"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab05cbastion.name
}

resource "azurerm_network_security_rule" "lab05cbastion_inbound_host_comm" {
  name                        = "AllowBastionHostCommunicationInbound"
  priority                    = 150
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_port_ranges     = ["8080", "5701"]
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab05cbastion.name
}

# Outbound rules for Bastion
resource "azurerm_network_security_rule" "lab05cbastion_outbound_ssh_rdp" {
  name                        = "AllowSshRdpOutbound"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "*"
  destination_port_ranges     = ["22", "3389"]
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab05cbastion.name
}

resource "azurerm_network_security_rule" "lab05cbastion_outbound_azure" {
  name                        = "AllowAzureCloudOutbound"
  priority                    = 110
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "*"
  destination_port_range      = "443"
  destination_address_prefix  = "AzureCloud"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab05cbastion.name
}

resource "azurerm_network_security_rule" "lab05cbastion_outbound_host_comm" {
  name                        = "AllowBastionHostCommunicationOutbound"
  priority                    = 120
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_port_ranges     = ["8080", "5701"]
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab05cbastion.name
}

resource "azurerm_network_security_rule" "lab05cbastion_outbound_session" {
  name                        = "AllowHttpOutbound"
  priority                    = 130
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  source_address_prefix       = "*"
  destination_port_range      = "80"
  destination_address_prefix  = "Internet"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab05cbastion.name
}

resource "azurerm_subnet_network_security_group_association" "lab05cbastion" {
  subnet_id                 = azurerm_subnet.lab05cbastion.id
  network_security_group_id = azurerm_network_security_group.lab05cbastion.id
}

resource "azurerm_public_ip" "lab05c" {
  name                = "${local.lab05c_name}-pip-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.default_tags
}

resource "azurerm_bastion_host" "lab05c" {
  name                   = "${local.lab05c_name}-bastion-${local.random_str}"
  location               = azurerm_resource_group.az104.location
  resource_group_name    = azurerm_resource_group.az104.name
  sku                    = "Standard"
  file_copy_enabled      = true
  ip_connect_enabled     = true
  shareable_link_enabled = true
  tunneling_enabled      = true

  ip_configuration {
    name                 = "${local.lab05c_name}-bastion-ipconfig-${local.random_str}"
    subnet_id            = azurerm_subnet.lab05cbastion.id
    public_ip_address_id = azurerm_public_ip.lab05c.id
  }
  tags = local.default_tags
}

resource "azurerm_network_interface" "lab05c" {
  name                = "${local.lab05c_name}-nic-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab05c_name}-nic-ipconfig-${local.random_str}"
    subnet_id                     = azurerm_subnet.lab05cdefault.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = local.default_tags
}

resource "azurerm_windows_virtual_machine" "lab05c" {
  name                  = "${local.lab05c_name}-vm-${local.random_str}"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab05c.id]
  size                  = local.vm_size

  os_disk {
    name                 = "${local.lab05c_name}-osdisk-${local.random_str}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab05c_name}-vm-${local.random_str}"
  admin_username = local.user_name
  admin_password = local.user_password

  identity {
    type = "SystemAssigned"
  }

  tags = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab05cama" {
  name                       = "AzureMonitorWindowsAgent"
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05c.id
  tags                       = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab05cda" {
  name                       = "DependencyAgentWindows"
  publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                       = "DependencyAgentWindows"
  type_handler_version       = "9.10"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05c.id

  settings = jsonencode({
    enableAMA = "true"
  })

  tags = local.default_tags

  depends_on = [azurerm_virtual_machine_extension.lab05cama]
}

resource "azurerm_monitor_data_collection_rule_association" "lab05c" {
  name                    = "lab05c-dcra"
  target_resource_id      = azurerm_windows_virtual_machine.lab05c.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vminsights.id
  description             = "VM Insights DCR association for lab05c"
}

resource "azurerm_virtual_machine_extension" "lab05c" {
  name                       = "${local.lab05c_name}-script-${local.random_str}"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05c.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS
  tags     = local.default_tags
}

resource "azurerm_storage_account" "lab05c" {
  name                            = "${local.lab05c_name}stor${local.random_str}"
  resource_group_name             = azurerm_resource_group.az104.name
  location                        = azurerm_resource_group.az104.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  public_network_access_enabled = false
  tags                            = local.default_tags
}

resource "azurerm_private_endpoint" "lab05c" {
  name                = "${local.lab05c_name}-private-endpoint-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  subnet_id           = azurerm_subnet.lab05cdefault.id

  private_service_connection {
    name                           = "${local.lab05c_name}-private-link-${local.random_str}"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.lab05c.id
    subresource_names              = ["blob"]
  }
  tags = local.default_tags

  # Should be deployed by Azure policy
  # lifecycle {
  #   ignore_changes = [private_dns_zone_group]
  # }
}
