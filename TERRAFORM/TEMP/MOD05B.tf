# LAB-05-B-VPN
resource "azurerm_virtual_network" "lab05b" {
  name                = "${local.lab05b_name}-vnet-${local.random_str}"
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
  name                = "${local.lab05b_name}-pip-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  allocation_method = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "lab05b" {
  name                = "${local.lab05b_name}-vnetgw-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = "VpnGw3"

  ip_configuration {
    name                          = "${local.lab05b_name}-vnetgw-ipconfig-${local.random_str}"
    public_ip_address_id          = azurerm_public_ip.lab05b.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.lab05bgateway.id
  }

  vpn_client_configuration {
    address_space = ["10.2.1.0/24"]

    root_certificate {
      name = "P2SRootCert"

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
  }
}

resource "azurerm_local_network_gateway" "lab05b" {
  name                = "${local.lab05b_name}-localgw-${local.random_str}"
  resource_group_name = azurerm_resource_group.az104.name
  location            = azurerm_resource_group.az104.location
  gateway_address     = "114.32.33.212"
  address_space       = ["192.168.112.0/24"]
}

resource "azurerm_network_security_group" "lab05b" {
  name                = "${local.lab05b_name}-nsg-${local.random_str}"
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
  name                = "${local.lab05b_name}-nic-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab05b_name}-nic-ipconfig-${local.random_str}"
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
  name                  = "${local.lab05b_name}-vm-${local.random_str}"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab05b.id]
  size                  = local.vm_size

  os_disk {
    name                 = "${local.lab05b_name}-osdisk-${local.random_str}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab05b_name}-vm-${local.random_str}"
  admin_username = local.user_name
  admin_password = local.user_passowrd

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_machine_extension" "lab05baad" {
  name                       = "${local.lab05b_name}-aad-${local.random_str}"
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
  name                       = "${local.lab05b_name}-script-${local.random_str}"
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