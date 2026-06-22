# LAB-05-D-VWAN
locals {
  lab05d_loc_01  = "japaneast"
  lab05d_loc_02  = "japanwest"
  lab05d_loc_03  = "eastasia"
  lab05d_vm_size = "Standard_D2s_v5"
}

resource "azurerm_virtual_network" "lab05d01" {
  name                = "${local.lab05d_name}-vnet01-jpe-${local.random_str}"
  address_space       = ["10.11.1.0/24"]
  location            = local.lab05d_loc_01
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_subnet" "lab05d01" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab05d01.name
  address_prefixes     = ["10.11.1.0/27"]
}

resource "azurerm_virtual_network" "lab05d02" {
  name                = "${local.lab05d_name}-vnet02-jpw-${local.random_str}"
  address_space       = ["10.12.1.0/24"]
  location            = local.lab05d_loc_02
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_subnet" "lab05d02" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab05d02.name
  address_prefixes     = ["10.12.1.0/27"]
}

resource "azurerm_virtual_network" "lab05d03" {
  name                = "${local.lab05d_name}-vnet03-ea-${local.random_str}"
  address_space       = ["10.13.1.0/24"]
  location            = local.lab05d_loc_03
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_subnet" "lab05d03" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab05d03.name
  address_prefixes     = ["10.13.1.0/27"]
}

resource "azurerm_virtual_wan" "lab05d" {
  name                = "${local.lab05d_name}-vwan-${local.random_str}"
  resource_group_name = azurerm_resource_group.az104.name
  location            = azurerm_resource_group.az104.location
  tags                = local.default_tags
}

resource "azurerm_virtual_hub" "lab05d01" {
  name                = "${local.lab05d_name}-hub01-jpe-${local.random_str}"
  resource_group_name = azurerm_resource_group.az104.name
  location            = local.lab05d_loc_01
  virtual_wan_id      = azurerm_virtual_wan.lab05d.id
  address_prefix      = "10.11.0.0/24"
  tags                = local.default_tags
}

resource "azurerm_virtual_hub" "lab05d02" {
  name                = "${local.lab05d_name}-hub02-jpw-${local.random_str}"
  resource_group_name = azurerm_resource_group.az104.name
  location            = local.lab05d_loc_02
  virtual_wan_id      = azurerm_virtual_wan.lab05d.id
  address_prefix      = "10.12.0.0/24"
  tags                = local.default_tags
}

resource "azurerm_virtual_hub" "lab05d03" {
  name                = "${local.lab05d_name}-hub03-ea-${local.random_str}"
  resource_group_name = azurerm_resource_group.az104.name
  location            = local.lab05d_loc_03
  virtual_wan_id      = azurerm_virtual_wan.lab05d.id
  address_prefix      = "10.13.0.0/24"
  tags                = local.default_tags
}

resource "azurerm_virtual_hub_connection" "lab05d01" {
  name                      = "${local.lab05d_name}-vnet01-conn-jpe-${local.random_str}"
  virtual_hub_id            = azurerm_virtual_hub.lab05d01.id
  remote_virtual_network_id = azurerm_virtual_network.lab05d01.id
}

resource "azurerm_virtual_hub_connection" "lab05d02" {
  name                      = "${local.lab05d_name}-vnet02-conn-jpw-${local.random_str}"
  virtual_hub_id            = azurerm_virtual_hub.lab05d02.id
  remote_virtual_network_id = azurerm_virtual_network.lab05d02.id
}

resource "azurerm_virtual_hub_connection" "lab05d03" {
  name                      = "${local.lab05d_name}-vnet03-conn-ea-${local.random_str}"
  virtual_hub_id            = azurerm_virtual_hub.lab05d03.id
  remote_virtual_network_id = azurerm_virtual_network.lab05d03.id
}

resource "azurerm_network_security_group" "lab05d01" {
  name                = "${local.lab05d_name}-nsg01-jpe-${local.random_str}"
  location            = local.lab05d_loc_01
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_network_security_group" "lab05d02" {
  name                = "${local.lab05d_name}-nsg02-jpw-${local.random_str}"
  location            = local.lab05d_loc_02
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_network_security_group" "lab05d03" {
  name                = "${local.lab05d_name}-nsg03-ea-${local.random_str}"
  location            = local.lab05d_loc_03
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_network_interface" "lab05d01" {
  name                = "${local.lab05d_name}-nic01-jpe-${local.random_str}"
  location            = local.lab05d_loc_01
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab05d_name}-ipconfig-01-${local.random_str}"
    subnet_id                     = azurerm_subnet.lab05d01.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = local.default_tags
}

resource "azurerm_subnet_network_security_group_association" "lab05d01" {
  subnet_id                 = azurerm_subnet.lab05d01.id
  network_security_group_id = azurerm_network_security_group.lab05d01.id
}

resource "azurerm_network_interface" "lab05d02" {
  name                = "${local.lab05d_name}-nic02-jpw-${local.random_str}"
  location            = local.lab05d_loc_02
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab05d_name}-ipconfig-02-${local.random_str}"
    subnet_id                     = azurerm_subnet.lab05d02.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = local.default_tags
}

resource "azurerm_subnet_network_security_group_association" "lab05d02" {
  subnet_id                 = azurerm_subnet.lab05d02.id
  network_security_group_id = azurerm_network_security_group.lab05d02.id
}

resource "azurerm_network_interface" "lab05d03" {
  name                = "${local.lab05d_name}-nic03-ea-${local.random_str}"
  location            = local.lab05d_loc_03
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab05d_name}-ipconfig-03-${local.random_str}"
    subnet_id                     = azurerm_subnet.lab05d03.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = local.default_tags
}

resource "azurerm_subnet_network_security_group_association" "lab05d03" {
  subnet_id                 = azurerm_subnet.lab05d03.id
  network_security_group_id = azurerm_network_security_group.lab05d03.id
}

resource "azurerm_windows_virtual_machine" "lab05d01" {
  name                  = "${local.lab05d_name}-vm01-${local.random_str}"
  location              = local.lab05d_loc_01
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab05d01.id]
  size                  = local.lab05d_vm_size

  os_disk {
    name                 = "${local.lab05d_name}-osdisk-01-${local.random_str}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab05d_name}-vm01-${local.random_str}"
  admin_username = local.user_name
  admin_password = local.user_password

  identity {
    type = "SystemAssigned"
  }

  tags = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab05d01ama" {
  name                       = "AzureMonitorWindowsAgent"
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05d01.id
  tags                       = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab05d01da" {
  name                       = "DependencyAgentWindows"
  publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                       = "DependencyAgentWindows"
  type_handler_version       = "9.10"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05d01.id

  settings = jsonencode({
    enableAMA = "true"
  })

  tags = local.default_tags

  depends_on = [azurerm_virtual_machine_extension.lab05d01ama]
}

resource "azurerm_monitor_data_collection_rule_association" "lab05d01" {
  name                    = "lab05d01-dcra"
  target_resource_id      = azurerm_windows_virtual_machine.lab05d01.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vminsights.id
  description             = "VM Insights DCR association for lab05d01"
}

resource "azurerm_virtual_machine_extension" "lab05d01script" {
  name                       = "${local.lab05d_name}-script-01-${local.random_str}"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05d01.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS
  tags     = local.default_tags
}

resource "azurerm_windows_virtual_machine" "lab05d02" {
  name                  = "${local.lab05d_name}-vm02-${local.random_str}"
  location              = local.lab05d_loc_02
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab05d02.id]
  size                  = local.lab05d_vm_size

  os_disk {
    name                 = "${local.lab05d_name}-osdisk-02-${local.random_str}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab05d_name}-vm02-${local.random_str}"
  admin_username = local.user_name
  admin_password = local.user_password

  identity {
    type = "SystemAssigned"
  }

  tags = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab05d02ama" {
  name                       = "AzureMonitorWindowsAgent"
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05d02.id
  tags                       = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab05d02da" {
  name                       = "DependencyAgentWindows"
  publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                       = "DependencyAgentWindows"
  type_handler_version       = "9.10"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05d02.id

  settings = jsonencode({
    enableAMA = "true"
  })

  tags = local.default_tags

  depends_on = [azurerm_virtual_machine_extension.lab05d02ama]
}

resource "azurerm_monitor_data_collection_rule_association" "lab05d02" {
  name                    = "lab05d02-dcra"
  target_resource_id      = azurerm_windows_virtual_machine.lab05d02.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vminsights.id
  description             = "VM Insights DCR association for lab05d02"
}

resource "azurerm_virtual_machine_extension" "lab05d02script" {
  name                       = "${local.lab05d_name}-script-02-${local.random_str}"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05d02.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS
  tags     = local.default_tags
}

resource "azurerm_windows_virtual_machine" "lab05d03" {
  name                  = "${local.lab05d_name}-vm03-${local.random_str}"
  location              = local.lab05d_loc_03
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab05d03.id]
  size                  = local.lab05d_vm_size

  os_disk {
    name                 = "${local.lab05d_name}-osdisk-03-${local.random_str}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab05d_name}-vm03-${local.random_str}"
  admin_username = local.user_name
  admin_password = local.user_password

  identity {
    type = "SystemAssigned"
  }

  tags = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab05d03ama" {
  name                       = "AzureMonitorWindowsAgent"
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05d03.id
  tags                       = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab05d03da" {
  name                       = "DependencyAgentWindows"
  publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                       = "DependencyAgentWindows"
  type_handler_version       = "9.10"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05d03.id

  settings = jsonencode({
    enableAMA = "true"
  })

  tags = local.default_tags

  depends_on = [azurerm_virtual_machine_extension.lab05d03ama]
}

resource "azurerm_monitor_data_collection_rule_association" "lab05d03" {
  name                    = "lab05d03-dcra"
  target_resource_id      = azurerm_windows_virtual_machine.lab05d03.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vminsights.id
  description             = "VM Insights DCR association for lab05d03"
}

resource "azurerm_virtual_machine_extension" "lab05d03script" {
  name                       = "${local.lab05d_name}-script-03-${local.random_str}"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab05d03.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS
  tags     = local.default_tags
}

resource "azurerm_vpn_server_configuration" "lab05d01" {
  name                     = "${local.lab05d_name}-vpnsvr01-jpe-${local.random_str}"
  resource_group_name      = azurerm_resource_group.az104.name
  location                 = local.lab05d_loc_01
  vpn_authentication_types = ["Certificate"]
  vpn_protocols            = ["IkeV2", "OpenVPN"]

  client_root_certificate {
    name             = "P2SRootCert"
    public_cert_data = <<EOF
MIIC6TCCAdGgAwIBAgIQXqUDrgdRmZVBz5E3J+jz1TANBgkqhkiG9w0BAQsFADAW
MRQwEgYDVQQDDAtQMlNSb290Q2VydDAgFw0yMTExMjgxMzUyMTdaGA8yMDk5MTIz
MDE2MDAwMFowFjEUMBIGA1UEAwwLUDJTUm9vdENlcnQwggEiMA0GCSqGSIb3DQEB
AQUAA4IBDwAwggEKAoIBAQDFZcgHM2zSyBYUWmi/N4y9BZeqIbLaVJXJbICAcCww
cgnR7LLtBe607mWCkOupTVlkg61Yf64bn5H0R7mkXAChA9vuk0NaHxvhkCsSQQoc
4GOfXjYXvuwHM8bGvT4Wk2sMLPCK03xj+RX6KskVqmjXesG0/4qCoQcY3JsgJGhL
QRCX4KD5hYopD0PU54SIQU5vxr7kb9+evx1pDpOI7tLdon02DGZ7J7yi8+3+qkFN
JlPdCPZNqvyNdKpIIWl4RKadfzrOirAzHtvvBN455eEbuH/qPGC8OiIYGeSTS04K
VPOYosKJDEXlnTmbo0ySUvRgqTmXJdpDkWKa8l5u6zodAgMBAAGjMTAvMA4GA1Ud
DwEB/wQEAwICBDAdBgNVHQ4EFgQUHdp6ZhvCBDsQQUIahU2dy0omt50wDQYJKoZI
hvcNAQELBQADggEBAMUh/0XrddTmI7VjJjSc01WVThx82r/IXVsNfl+ed13h3+Rp
1r3FELUTiozyYIUus70uiMf+qXDdPI3I7lPRMENoQNCxEyPhdD5awc12TBRP/c8W
QwqTA9lhoERvQ6oDQqZIGcARHFdq0qk1Ci/ZDDw1Oq70xSFhSZqMo2VDwKtuh2gT
pgEzE0JQpt9OOUI1EzLrx/nun6t/wxAXSyLev+0rt9dNr0MSD8DfqtFYiQWL5C44
nitvjgOQlGGE5LAR061qUaSwc3CMSOniaDjASGXVmF55lIEFeCg+yg/5Na7IVRCb
+ZNNQGtMCTBWZI7WJ9A8PwdhFw6412aBK9AKsvk=
EOF
  }
  tags = local.default_tags
}

resource "azurerm_point_to_site_vpn_gateway" "lab05d01" {
  name                        = "${local.lab05d_name}-p2s-vpngw01-jpe-${local.random_str}"
  resource_group_name         = azurerm_resource_group.az104.name
  location                    = local.lab05d_loc_01
  virtual_hub_id              = azurerm_virtual_hub.lab05d01.id
  vpn_server_configuration_id = azurerm_vpn_server_configuration.lab05d01.id
  scale_unit                  = 1
  connection_configuration {
    name = "${local.lab05d_name}-p2s-config01-jpe-${local.random_str}"

    vpn_client_address_pool {
      address_prefixes = [
        "10.11.2.0/24"
      ]
    }
  }
  tags = local.default_tags
}
