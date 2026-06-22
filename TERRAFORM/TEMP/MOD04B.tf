## LAB-04B-PRIVATE-DNS
# Self-contained Azure Private DNS demo, isolated from the lab04 Azure Firewall scenario.
#
#   VNet-A (10.40.0.0/16) is LINKED to the private zone with registration_enabled = true,
#     so vm-a1 and vm-a2 auto-register their A records and can resolve each other by name.
#   VNet-B (10.41.0.0/16) is intentionally NOT linked, so vm-b1 cannot resolve the private
#     records until a link is added live during the demo.
#
# Key detail: the demo VMs do NOT set custom dns_servers on their NICs, so they use the
# Azure-provided DNS (168.63.129.16). That is mandatory for Private DNS zone resolution to
# work -- this is exactly what the lab04 firewall VM (dns_servers = 8.8.8.8) cannot do.

# ---------------------------------------------------------------------------
# Shared NSG (RDP from the trainer's current public IP), used by both subnets
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "lab04b" {
  name                = "${local.lab04b_name}-nsg-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_network_security_rule" "lab04b_rdp" {
  name                        = "RDP"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = chomp(data.http.myip.response_body)
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab04b.name
}

# ---------------------------------------------------------------------------
# VNet-A -- linked to the private DNS zone (autoregistration ON)
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "lab04b_a" {
  name                = "${local.lab04b_name}-vnet-a-${local.random_str}"
  address_space       = ["10.40.0.0/16"]
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_subnet" "lab04b_a" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab04b_a.name
  address_prefixes     = ["10.40.1.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "lab04b_a" {
  subnet_id                 = azurerm_subnet.lab04b_a.id
  network_security_group_id = azurerm_network_security_group.lab04b.id
}

# ---------------------------------------------------------------------------
# VNet-B -- intentionally NOT linked to the private DNS zone
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "lab04b_b" {
  name                = "${local.lab04b_name}-vnet-b-${local.random_str}"
  address_space       = ["10.41.0.0/16"]
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_subnet" "lab04b_b" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab04b_b.name
  address_prefixes     = ["10.41.1.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "lab04b_b" {
  subnet_id                 = azurerm_subnet.lab04b_b.id
  network_security_group_id = azurerm_network_security_group.lab04b.id
}

# ---------------------------------------------------------------------------
# Private DNS zone + VNet-A link + a manual A record
# ---------------------------------------------------------------------------
resource "azurerm_private_dns_zone" "lab04b" {
  name                = "corp.contoso.com"
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

# VNet-A linked WITH autoregistration -> vm-a1 / vm-a2 auto-register their A records.
resource "azurerm_private_dns_zone_virtual_network_link" "lab04b_a" {
  name                  = "${local.lab04b_name}-link-a-${local.random_str}"
  resource_group_name   = azurerm_resource_group.az104.name
  private_dns_zone_name = azurerm_private_dns_zone.lab04b.name
  virtual_network_id    = azurerm_virtual_network.lab04b_a.id
  registration_enabled  = true
  tags                  = local.default_tags
}

# NOTE: VNet-B is deliberately left UNLINKED so the demo can show that an unlinked VNet
# cannot resolve the zone. During the live demo, add a resolution-only link (registration
# disabled) to show the before/after difference, e.g.:
#   New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName <rg> -ZoneName corp.contoso.com \
#     -Name link-b -VirtualNetworkId <vnet-b-id>   # do NOT pass -EnableRegistration

# Manual A record: deterministic, independent of autoregistration timing.
resource "azurerm_private_dns_a_record" "lab04b_app" {
  name                = "app"
  zone_name           = azurerm_private_dns_zone.lab04b.name
  resource_group_name = azurerm_resource_group.az104.name
  ttl                 = 300
  records             = ["10.40.1.100"]
  tags                = local.default_tags
}

# ---------------------------------------------------------------------------
# Public IPs (one per VM, RDP access from the trainer's IP)
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "lab04b_a1" {
  name                = "${local.lab04b_name}-pip-a1-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.default_tags

  lifecycle {
    ignore_changes = [ip_tags]
  }
}

resource "azurerm_public_ip" "lab04b_a2" {
  name                = "${local.lab04b_name}-pip-a2-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.default_tags

  lifecycle {
    ignore_changes = [ip_tags]
  }
}

resource "azurerm_public_ip" "lab04b_b1" {
  name                = "${local.lab04b_name}-pip-b1-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.default_tags

  lifecycle {
    ignore_changes = [ip_tags]
  }
}

# ---------------------------------------------------------------------------
# NICs -- NO custom dns_servers, so the VMs use Azure DNS (168.63.129.16)
# ---------------------------------------------------------------------------
resource "azurerm_network_interface" "lab04b_a1" {
  name                = "${local.lab04b_name}-nic-a1-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.lab04b_a.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.lab04b_a1.id
  }
  tags = local.default_tags
}

resource "azurerm_network_interface" "lab04b_a2" {
  name                = "${local.lab04b_name}-nic-a2-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.lab04b_a.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.lab04b_a2.id
  }
  tags = local.default_tags
}

resource "azurerm_network_interface" "lab04b_b1" {
  name                = "${local.lab04b_name}-nic-b1-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.lab04b_b.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.lab04b_b1.id
  }
  tags = local.default_tags
}

# ---------------------------------------------------------------------------
# VMs -- Windows Server 2022, Standard_B2s.
# computer_name is kept <= 15 chars (NetBIOS limit) so the autoregistered FQDNs are
# vm-a1.corp.contoso.com / vm-a2.corp.contoso.com / vm-b1.corp.contoso.com
# ---------------------------------------------------------------------------
resource "azurerm_windows_virtual_machine" "lab04b_a1" {
  name                  = "${local.lab04b_name}-vm-a1-${local.random_str}"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab04b_a1.id]
  size                  = "Standard_B2s"

  os_disk {
    name                 = "${local.lab04b_name}-osdisk-a1-${local.random_str}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  computer_name  = "vm-a1"
  admin_username = local.user_name
  admin_password = local.user_password

  tags = local.default_tags
}

resource "azurerm_windows_virtual_machine" "lab04b_a2" {
  name                  = "${local.lab04b_name}-vm-a2-${local.random_str}"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab04b_a2.id]
  size                  = "Standard_B2s"

  os_disk {
    name                 = "${local.lab04b_name}-osdisk-a2-${local.random_str}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  computer_name  = "vm-a2"
  admin_username = local.user_name
  admin_password = local.user_password

  tags = local.default_tags
}

resource "azurerm_windows_virtual_machine" "lab04b_b1" {
  name                  = "${local.lab04b_name}-vm-b1-${local.random_str}"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab04b_b1.id]
  size                  = "Standard_B2s"

  os_disk {
    name                 = "${local.lab04b_name}-osdisk-b1-${local.random_str}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  computer_name  = "vm-b1"
  admin_username = local.user_name
  admin_password = local.user_password

  tags = local.default_tags
}
