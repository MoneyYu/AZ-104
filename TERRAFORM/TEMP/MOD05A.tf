## LAB-05-A-PEERING
variable "lab05a_enable_transit_routing" {
  description = "Associates the VNet2 and VNet3 subnets with routes that send transit traffic through VM01."
  type        = bool
  default     = false
}

resource "azurerm_virtual_network" "lab05a01" {
  name                = "${local.lab05a_name}-vnet-01-${local.random_str}"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_subnet" "lab05a01" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab05a01.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_public_ip" "lab05a01" {
  name                = "${local.lab05a_name}-pip-01-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${local.lab05a_name}-pip-01-${local.random_str}"
  tags                = local.default_tags

  lifecycle {
    ignore_changes = [ip_tags]
  }
}

resource "azurerm_network_security_group" "lab05a_jpe" {
  name                = "${local.lab05a_name}-nsg-jpe-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_network_security_rule" "lab05a_jpe" {
  name                        = "RDP"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = chomp(data.http.myip.response_body)
  destination_port_range      = "3389"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab05a_jpe.name
}

resource "azurerm_network_interface" "lab05a01" {
  name                  = "${local.lab05a_name}-nic-01-${local.random_str}"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  ip_forwarding_enabled = true

  ip_configuration {
    name                          = "${local.lab05a_name}-ipconfig-01-${local.random_str}"
    subnet_id                     = azurerm_subnet.lab05a01.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.1.1.4"
    public_ip_address_id          = azurerm_public_ip.lab05a01.id
  }
  tags = local.default_tags
}

resource "azurerm_subnet_network_security_group_association" "lab05a01" {
  subnet_id                 = azurerm_subnet.lab05a01.id
  network_security_group_id = azurerm_network_security_group.lab05a_jpe.id
}

resource "azurerm_windows_virtual_machine" "lab05a01" {
  name                  = "${local.lab05a_name}-vm01-${local.random_str}"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab05a01.id]
  size                  = local.vm_size

  os_disk {
    name                 = "${local.lab05a_name}-osdisk-01-${local.random_str}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab05a_name}-vm01-${local.random_str}"
  admin_username = local.user_name
  admin_password = local.user_password

  identity {
    type = "SystemAssigned"
  }

  tags = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab05a01ama" {
  name                       = "AzureMonitorWindowsAgent"
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05a01.id
  tags                       = local.default_tags
}

resource "azurerm_monitor_data_collection_rule_association" "lab05a01" {
  name                    = "lab05a01-dcra"
  target_resource_id      = azurerm_windows_virtual_machine.lab05a01.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vminsights.id
  description             = "VM Insights DCR association for lab05a01"
}

resource "azurerm_monitor_data_collection_rule_association" "lab05a01_otel" {
  name                    = "lab05a01-otel-dcra"
  target_resource_id      = azurerm_windows_virtual_machine.lab05a01.id
  data_collection_rule_id = azapi_resource.vminsights_otel.id
  description             = "OpenTelemetry metrics DCR association for lab05a01"
}

resource "azurerm_virtual_machine_extension" "lab05a01script" {
  name                       = "${local.lab05a_name}-script-01-${local.random_str}"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05a01.id

  settings = jsonencode({
    commandToExecute = <<-COMMAND
      powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { try { Install-WindowsFeature -Name Web-Server,RemoteAccess,Routing -IncludeManagementTools -ErrorAction Stop; Set-Content -Path 'C:\inetpub\wwwroot\iisstart.htm' -Value ('Hello World from ' + $env:computername) -ErrorAction Stop } catch { Write-Error ('IIS and routing role setup failed: ' + $_.Exception.Message) -ErrorAction Continue }; try { New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'IPEnableRouter' -PropertyType DWord -Value 1 -Force -ErrorAction Stop | Out-Null } catch { Write-Error ('IP forwarding registry setup failed: ' + $_.Exception.Message) -ErrorAction Continue }; try { $remoteAccess = Get-RemoteAccess -ErrorAction SilentlyContinue; if ($null -eq $remoteAccess -or $remoteAccess.RoutingStatus -ne 'Installed') { Install-RemoteAccess -VpnType RoutingOnly -ErrorAction Stop } } catch { Write-Error ('RRAS configuration failed: ' + $_.Exception.Message) -ErrorAction Continue }; try { Set-Service -Name RemoteAccess -StartupType Automatic -ErrorAction Stop; Start-Service -Name RemoteAccess -ErrorAction Stop } catch { Write-Error ('RemoteAccess service setup failed: ' + $_.Exception.Message) -ErrorAction Continue }; try { Enable-NetFirewallRule -Name 'FPS-ICMP4-ERQ-In' -ErrorAction Stop } catch { Write-Error ('ICMP firewall rule setup failed: ' + $_.Exception.Message) -ErrorAction Continue }; exit 0 }"
    COMMAND
  })
  tags = local.default_tags
}

resource "azurerm_virtual_network" "lab05a02" {
  name                = "${local.lab05a_name}-vnet-02-${local.random_str}"
  address_space       = ["10.2.0.0/16"]
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_subnet" "lab05a02" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab05a02.name
  address_prefixes     = ["10.2.1.0/24"]

  # Demo route-table associations are created outside Terraform, so keep subnet destroy ahead of route table destroy.
  depends_on = [azurerm_route_table.lab05a_spoke2]
}

resource "azurerm_public_ip" "lab05a02" {
  name                = "${local.lab05a_name}-pip-02-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${local.lab05a_name}-pip-02-${local.random_str}"
  tags                = local.default_tags

  lifecycle {
    ignore_changes = [ip_tags]
  }
}

resource "azurerm_network_interface" "lab05a02" {
  name                = "${local.lab05a_name}-nic-02-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab05a_name}-ipconfig-02-${local.random_str}"
    subnet_id                     = azurerm_subnet.lab05a02.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.lab05a02.id
  }
  tags = local.default_tags
}

resource "azurerm_subnet_network_security_group_association" "lab05a02" {
  subnet_id                 = azurerm_subnet.lab05a02.id
  network_security_group_id = azurerm_network_security_group.lab05a_jpe.id
}

resource "azurerm_windows_virtual_machine" "lab05a02" {
  name                  = "${local.lab05a_name}-vm02-${local.random_str}"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab05a02.id]
  size                  = local.vm_size

  os_disk {
    name                 = "${local.lab05a_name}-osdisk-02-${local.random_str}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab05a_name}-vm02-${local.random_str}"
  admin_username = local.user_name
  admin_password = local.user_password

  identity {
    type = "SystemAssigned"
  }

  tags = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab05a02ama" {
  name                       = "AzureMonitorWindowsAgent"
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05a02.id
  tags                       = local.default_tags
}

resource "azurerm_monitor_data_collection_rule_association" "lab05a02" {
  name                    = "lab05a02-dcra"
  target_resource_id      = azurerm_windows_virtual_machine.lab05a02.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vminsights.id
  description             = "VM Insights DCR association for lab05a02"
}

resource "azurerm_monitor_data_collection_rule_association" "lab05a02_otel" {
  name                    = "lab05a02-otel-dcra"
  target_resource_id      = azurerm_windows_virtual_machine.lab05a02.id
  data_collection_rule_id = azapi_resource.vminsights_otel.id
  description             = "OpenTelemetry metrics DCR association for lab05a02"
}

resource "azurerm_virtual_machine_extension" "lab05a02script" {
  name                       = "${local.lab05a_name}-script-02-${local.random_str}"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05a02.id

  settings = jsonencode({
    commandToExecute = <<-COMMAND
      powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { try { Install-WindowsFeature -Name Web-Server -IncludeManagementTools -ErrorAction Stop; Set-Content -Path 'C:\inetpub\wwwroot\iisstart.htm' -Value ('Hello World from ' + $env:computername) -ErrorAction Stop } catch { Write-Error ('IIS setup failed: ' + $_.Exception.Message) -ErrorAction Continue }; try { Enable-NetFirewallRule -Name 'FPS-ICMP4-ERQ-In' -ErrorAction Stop } catch { Write-Error ('ICMP firewall rule setup failed: ' + $_.Exception.Message) -ErrorAction Continue }; exit 0 }"
    COMMAND
  })
  tags = local.default_tags
}

resource "azurerm_virtual_network" "lab05a03" {
  name                = "${local.lab05a_name}-vnet-03-${local.random_str}"
  address_space       = ["10.3.0.0/16"]
  location            = "eastasia"
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_subnet" "lab05a03" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab05a03.name
  address_prefixes     = ["10.3.1.0/24"]

  # Demo route-table associations are created outside Terraform, so keep subnet destroy ahead of route table destroy.
  depends_on = [azurerm_route_table.lab05a_spoke3]
}

resource "azurerm_public_ip" "lab05a03" {
  name                = "${local.lab05a_name}-pip-03-${local.random_str}"
  location            = "eastasia"
  resource_group_name = azurerm_resource_group.az104.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${local.lab05a_name}-pip-03-${local.random_str}"
  tags                = local.default_tags

  lifecycle {
    ignore_changes = [ip_tags]
  }
}

resource "azurerm_network_security_group" "lab05a03" {
  name                = "${local.lab05a_name}-nsg-03-${local.random_str}"
  location            = "eastasia"
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_network_security_rule" "lab05a03" {
  name                        = "RDP"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = chomp(data.http.myip.response_body)
  destination_port_range      = "3389"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab05a03.name
}

resource "azurerm_network_interface" "lab05a03" {
  name                = "${local.lab05a_name}-nic-03-${local.random_str}"
  location            = "eastasia"
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab05a_name}-ipconfig-03-${local.random_str}"
    subnet_id                     = azurerm_subnet.lab05a03.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.lab05a03.id
  }
  tags = local.default_tags
}

resource "azurerm_subnet_network_security_group_association" "lab05a03" {
  subnet_id                 = azurerm_subnet.lab05a03.id
  network_security_group_id = azurerm_network_security_group.lab05a03.id
}

resource "azurerm_windows_virtual_machine" "lab05a03" {
  name                  = "${local.lab05a_name}-vm03-${local.random_str}"
  location              = "eastasia"
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab05a03.id]
  size                  = local.vm_size

  os_disk {
    name                 = "${local.lab05a_name}-osdisk-03-${local.random_str}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab05a_name}-vm03-${local.random_str}"
  admin_username = local.user_name
  admin_password = local.user_password

  identity {
    type = "SystemAssigned"
  }

  tags = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab05a03ama" {
  name                       = "AzureMonitorWindowsAgent"
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05a03.id
  tags                       = local.default_tags
}

resource "azurerm_monitor_data_collection_rule_association" "lab05a03" {
  name                    = "lab05a03-dcra"
  target_resource_id      = azurerm_windows_virtual_machine.lab05a03.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vminsights.id
  description             = "VM Insights DCR association for lab05a03"
}

resource "azurerm_monitor_data_collection_rule_association" "lab05a03_otel" {
  name                    = "lab05a03-otel-dcra"
  target_resource_id      = azurerm_windows_virtual_machine.lab05a03.id
  data_collection_rule_id = azapi_resource.vminsights_otel.id
  description             = "OpenTelemetry metrics DCR association for lab05a03"
}

resource "azurerm_virtual_machine_extension" "lab05a03script" {
  name                       = "${local.lab05a_name}-script-03-${local.random_str}"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05a03.id

  settings = jsonencode({
    commandToExecute = <<-COMMAND
      powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { try { Install-WindowsFeature -Name Web-Server -IncludeManagementTools -ErrorAction Stop; Set-Content -Path 'C:\inetpub\wwwroot\iisstart.htm' -Value ('Hello World from ' + $env:computername) -ErrorAction Stop } catch { Write-Error ('IIS setup failed: ' + $_.Exception.Message) -ErrorAction Continue }; try { Enable-NetFirewallRule -Name 'FPS-ICMP4-ERQ-In' -ErrorAction Stop } catch { Write-Error ('ICMP firewall rule setup failed: ' + $_.Exception.Message) -ErrorAction Continue }; exit 0 }"
    COMMAND
  })
  tags = local.default_tags
}

# Optional VNet2-to-VNet3 transit routing through VM01.
resource "azurerm_network_security_rule" "lab05a_jpe_allow_vnet3_inbound" {
  name                        = "Allow-VNet3-Inbound"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "10.3.0.0/16"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab05a_jpe.name
}

resource "azurerm_network_security_rule" "lab05a_jpe_allow_vnet3_outbound" {
  name                        = "Allow-VNet3-Outbound"
  priority                    = 200
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "10.3.0.0/16"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab05a_jpe.name
}

resource "azurerm_network_security_rule" "lab05a03_allow_vnet2_inbound" {
  name                        = "Allow-VNet2-Inbound"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "10.2.0.0/16"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab05a03.name
}

resource "azurerm_network_security_rule" "lab05a03_allow_vnet2_outbound" {
  name                        = "Allow-VNet2-Outbound"
  priority                    = 200
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "10.2.0.0/16"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab05a03.name
}

resource "azurerm_route_table" "lab05a_spoke2" {
  name                = "${local.lab05a_name}-rt-spoke2-${local.random_str}"
  location            = azurerm_virtual_network.lab05a02.location
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_route_table" "lab05a_spoke3" {
  name                = "${local.lab05a_name}-rt-spoke3-${local.random_str}"
  location            = azurerm_virtual_network.lab05a03.location
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_route" "lab05a_spoke2_to_vnet3" {
  name                   = "to-vnet3-via-vm01"
  resource_group_name    = azurerm_resource_group.az104.name
  route_table_name       = azurerm_route_table.lab05a_spoke2.name
  address_prefix         = "10.3.0.0/16"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = "10.1.1.4"
}

resource "azurerm_route" "lab05a_spoke3_to_vnet2" {
  name                   = "to-vnet2-via-vm01"
  resource_group_name    = azurerm_resource_group.az104.name
  route_table_name       = azurerm_route_table.lab05a_spoke3.name
  address_prefix         = "10.2.0.0/16"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = "10.1.1.4"
}

resource "azurerm_subnet_route_table_association" "lab05a02_transit" {
  count          = var.lab05a_enable_transit_routing ? 1 : 0
  subnet_id      = azurerm_subnet.lab05a02.id
  route_table_id = azurerm_route_table.lab05a_spoke2.id
}

resource "azurerm_subnet_route_table_association" "lab05a03_transit" {
  count          = var.lab05a_enable_transit_routing ? 1 : 0
  subnet_id      = azurerm_subnet.lab05a03.id
  route_table_id = azurerm_route_table.lab05a_spoke3.id
}

resource "azurerm_monitor_diagnostic_setting" "lab05a_jpe_nsg" {
  name                       = "lab05a-jpe-nsg-diag"
  target_resource_id         = azurerm_network_security_group.lab05a_jpe.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab05a03nsg" {
  name                       = "lab05a03-nsg-diag"
  target_resource_id         = azurerm_network_security_group.lab05a03.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab05a01pip" {
  name                       = "lab05a01-pip-diag"
  target_resource_id         = azurerm_public_ip.lab05a01.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab05a02pip" {
  name                       = "lab05a02-pip-diag"
  target_resource_id         = azurerm_public_ip.lab05a02.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab05a03pip" {
  name                       = "lab05a03-pip-diag"
  target_resource_id         = azurerm_public_ip.lab05a03.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab05a01vnet" {
  name                       = "lab05a01-vnet-diag"
  target_resource_id         = azurerm_virtual_network.lab05a01.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab05a02vnet" {
  name                       = "lab05a02-vnet-diag"
  target_resource_id         = azurerm_virtual_network.lab05a02.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab05a03vnet" {
  name                       = "lab05a03-vnet-diag"
  target_resource_id         = azurerm_virtual_network.lab05a03.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_metric {
    category = "AllMetrics"
  }
}
