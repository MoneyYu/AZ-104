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