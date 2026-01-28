## LAB-8B-VMSS
# This module creates a Virtual Machine Scale Set that uses the Bastion from MOD08.tf

# Create a separate subnet for VMSS in the same VNet
resource "azurerm_subnet" "lab08vmss" {
  name                 = "vmss-subnet"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab08.name
  address_prefixes     = ["10.10.3.0/24"]
}

# Create a Load Balancer for VMSS
resource "azurerm_public_ip" "lab08vmss" {
  name                = "${local.lab08_name}b-lb-pip-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.default_tags
}

resource "azurerm_lb" "lab08vmss" {
  name                = "${local.lab08_name}b-lb-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "${local.lab08_name}b-lb-frontend-${local.random_str}"
    public_ip_address_id = azurerm_public_ip.lab08vmss.id
  }
  tags = local.default_tags
}

resource "azurerm_lb_backend_address_pool" "lab08vmss" {
  loadbalancer_id = azurerm_lb.lab08vmss.id
  name            = "${local.lab08_name}b-lb-backend-${local.random_str}"
}

resource "azurerm_lb_probe" "lab08vmss" {
  loadbalancer_id = azurerm_lb.lab08vmss.id
  name            = "${local.lab08_name}b-lb-probe-${local.random_str}"
  protocol        = "Http"
  port            = 80
  request_path    = "/"
}

resource "azurerm_lb_rule" "lab08vmss" {
  loadbalancer_id                = azurerm_lb.lab08vmss.id
  name                           = "${local.lab08_name}b-lb-rule-${local.random_str}"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = azurerm_lb.lab08vmss.frontend_ip_configuration[0].name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lab08vmss.id]
  probe_id                       = azurerm_lb_probe.lab08vmss.id
  disable_outbound_snat          = true
}

# Outbound rule for internet access
resource "azurerm_lb_outbound_rule" "lab08vmss" {
  name                    = "${local.lab08_name}b-lb-outbound-${local.random_str}"
  loadbalancer_id         = azurerm_lb.lab08vmss.id
  protocol                = "All"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lab08vmss.id

  frontend_ip_configuration {
    name = azurerm_lb.lab08vmss.frontend_ip_configuration[0].name
  }
}

# Create Virtual Machine Scale Set
resource "azurerm_windows_virtual_machine_scale_set" "lab08vmss" {
  name                = "${local.lab08_name}b-vmss-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  sku                 = local.vm_size
  instances           = 2
  admin_username      = local.user_name
  admin_password      = local.user_password
  computer_name_prefix = "vmss"
  
  upgrade_mode = "Automatic"

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  network_interface {
    name    = "${local.lab08_name}b-vmss-nic-${local.random_str}"
    primary = true

    ip_configuration {
      name      = "${local.lab08_name}b-vmss-ipconfig-${local.random_str}"
      primary   = true
      subnet_id = azurerm_subnet.lab08vmss.id

      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.lab08vmss.id]
    }
  }

  tags = local.default_tags
}

# Install IIS on VMSS instances
resource "azurerm_virtual_machine_scale_set_extension" "lab08vmss_iis" {
  name                         = "${local.lab08_name}b-vmss-iis-${local.random_str}"
  virtual_machine_scale_set_id = azurerm_windows_virtual_machine_scale_set.lab08vmss.id
  publisher                    = "Microsoft.Compute"
  type                         = "CustomScriptExtension"
  type_handler_version         = "1.10"
  auto_upgrade_minor_version   = true

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from VMSS instance: ' + $env:computername)"
    }
  SETTINGS
}

# Enable AAD login for VMSS instances
resource "azurerm_virtual_machine_scale_set_extension" "lab08vmss_aad" {
  name                         = "${local.lab08_name}b-vmss-aad-${local.random_str}"
  virtual_machine_scale_set_id = azurerm_windows_virtual_machine_scale_set.lab08vmss.id
  publisher                    = "Microsoft.Azure.ActiveDirectory"
  type                         = "AADLoginForWindows"
  type_handler_version         = "1.0"
  auto_upgrade_minor_version   = true
}

# Output the Load Balancer public IP
output "lab08b_vmss_lb_public_ip" {
  value       = azurerm_public_ip.lab08vmss.ip_address
  description = "Public IP address of the Load Balancer for VMSS"
}

# Output the Bastion host name (from MOD08.tf)
output "lab08b_bastion_name" {
  value       = azurerm_bastion_host.lab08.name
  description = "Name of the Bastion host for connecting to VMSS instances"
}
