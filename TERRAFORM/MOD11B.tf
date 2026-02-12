## LAB-11B-SITE-RECOVERY

# =============================================================================
# DR Resource Group (Japan West)
# =============================================================================
resource "azurerm_resource_group" "lab11b_dr" {
  name     = "${local.group_name}-DR"
  location = "japanwest"
  tags     = local.default_tags
}

# =============================================================================
# Primary Region Network (Japan East)
# =============================================================================
resource "azurerm_virtual_network" "lab11b" {
  name                = "${local.lab11b_name}-vnet-${local.random_str}"
  address_space       = ["10.11.0.0/16"]
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_subnet" "lab11b" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab11b.name
  address_prefixes     = ["10.11.1.0/24"]
}

resource "azurerm_network_security_group" "lab11b" {
  name                = "${local.lab11b_name}-nsg-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

resource "azurerm_network_security_rule" "lab11b_http" {
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
  network_security_group_name = azurerm_network_security_group.lab11b.name
}

resource "azurerm_subnet_network_security_group_association" "lab11b" {
  subnet_id                 = azurerm_subnet.lab11b.id
  network_security_group_id = azurerm_network_security_group.lab11b.id
}

# =============================================================================
# Primary Load Balancer (Japan East)
# =============================================================================
resource "azurerm_public_ip" "lab11b" {
  name                = "${local.lab11b_name}-pip-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${local.lab11b_name}-pip-${local.random_str}"
  tags                = local.default_tags
}

resource "azurerm_lb" "lab11b" {
  name                = "${local.lab11b_name}-lb-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lab11b.id
  }
  tags = local.default_tags
}

resource "azurerm_lb_backend_address_pool" "lab11b" {
  loadbalancer_id = azurerm_lb.lab11b.id
  name            = "BackendPool"
}

resource "azurerm_lb_probe" "lab11b" {
  loadbalancer_id     = azurerm_lb.lab11b.id
  name                = "probe"
  port                = 80
  interval_in_seconds = 5
}

resource "azurerm_lb_rule" "lab11b" {
  loadbalancer_id                = azurerm_lb.lab11b.id
  name                           = "rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lab11b.id]
  probe_id                       = azurerm_lb_probe.lab11b.id
  disable_outbound_snat          = false
}

# =============================================================================
# VM 01 (Japan East)
# =============================================================================
resource "azurerm_network_interface" "lab11b01" {
  name                = "${local.lab11b_name}-nic-01-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab11b_name}-nic-ipconfig-01-${local.random_str}"
    subnet_id                     = azurerm_subnet.lab11b.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = local.default_tags
}

resource "azurerm_network_interface_security_group_association" "lab11b01" {
  network_interface_id      = azurerm_network_interface.lab11b01.id
  network_security_group_id = azurerm_network_security_group.lab11b.id
}

resource "azurerm_network_interface_backend_address_pool_association" "lab11b01" {
  network_interface_id    = azurerm_network_interface.lab11b01.id
  ip_configuration_name   = "${local.lab11b_name}-nic-ipconfig-01-${local.random_str}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lab11b.id
}

resource "azurerm_windows_virtual_machine" "lab11b01" {
  name                  = "${local.lab11b_name}-vm01-${local.random_str}"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab11b01.id]
  size                  = local.vm_size

  os_disk {
    name                 = "${local.lab11b_name}-osdisk-01-${local.random_str}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab11b_name}-vm01-${local.random_str}"
  admin_username = local.user_name
  admin_password = local.user_password

  identity {
    type = "SystemAssigned"
  }

  tags = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab11b01ama" {
  name                       = "AzureMonitorWindowsAgent"
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab11b01.id
  tags                       = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab11b01da" {
  name                       = "DependencyAgentWindows"
  publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                       = "DependencyAgentWindows"
  type_handler_version       = "9.10"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab11b01.id

  settings = jsonencode({
    enableAMA = "true"
  })

  tags = local.default_tags

  depends_on = [azurerm_virtual_machine_extension.lab11b01ama]
}

resource "azurerm_monitor_data_collection_rule_association" "lab11b01" {
  name                    = "lab11b01-dcra"
  target_resource_id      = azurerm_windows_virtual_machine.lab11b01.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vminsights.id
  description             = "VM Insights DCR association for lab11b01"
}

resource "azurerm_virtual_machine_extension" "lab11b01script" {
  name                       = "${local.lab11b_name}-script-01-${local.random_str}"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab11b01.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS
  tags     = local.default_tags
}

# =============================================================================
# VM 02 (Japan East)
# =============================================================================
resource "azurerm_network_interface" "lab11b02" {
  name                = "${local.lab11b_name}-nic-02-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab11b_name}-nic-ipconfig-02-${local.random_str}"
    subnet_id                     = azurerm_subnet.lab11b.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = local.default_tags
}

resource "azurerm_network_interface_security_group_association" "lab11b02" {
  network_interface_id      = azurerm_network_interface.lab11b02.id
  network_security_group_id = azurerm_network_security_group.lab11b.id
}

resource "azurerm_network_interface_backend_address_pool_association" "lab11b02" {
  network_interface_id    = azurerm_network_interface.lab11b02.id
  ip_configuration_name   = "${local.lab11b_name}-nic-ipconfig-02-${local.random_str}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lab11b.id
}

resource "azurerm_windows_virtual_machine" "lab11b02" {
  name                  = "${local.lab11b_name}-vm02-${local.random_str}"
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab11b02.id]
  size                  = local.vm_size

  os_disk {
    name                 = "${local.lab11b_name}-osdisk-02-${local.random_str}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  computer_name  = "${local.lab11b_name}-vm02-${local.random_str}"
  admin_username = local.user_name
  admin_password = local.user_password

  identity {
    type = "SystemAssigned"
  }

  tags = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab11b02ama" {
  name                       = "AzureMonitorWindowsAgent"
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab11b02.id
  tags                       = local.default_tags
}

resource "azurerm_virtual_machine_extension" "lab11b02da" {
  name                       = "DependencyAgentWindows"
  publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                       = "DependencyAgentWindows"
  type_handler_version       = "9.10"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab11b02.id

  settings = jsonencode({
    enableAMA = "true"
  })

  tags = local.default_tags

  depends_on = [azurerm_virtual_machine_extension.lab11b02ama]
}

resource "azurerm_monitor_data_collection_rule_association" "lab11b02" {
  name                    = "lab11b02-dcra"
  target_resource_id      = azurerm_windows_virtual_machine.lab11b02.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vminsights.id
  description             = "VM Insights DCR association for lab11b02"
}

resource "azurerm_virtual_machine_extension" "lab11b02script" {
  name                       = "${local.lab11b_name}-script-02-${local.random_str}"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab11b02.id

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername)"
    }
  SETTINGS
  tags     = local.default_tags
}

# =============================================================================
# DR Region Network (Japan West)
# =============================================================================
resource "azurerm_virtual_network" "lab11b_dr" {
  name                = "${local.lab11b_name}-dr-vnet-${local.random_str}"
  address_space       = ["10.12.0.0/16"]
  location            = azurerm_resource_group.lab11b_dr.location
  resource_group_name = azurerm_resource_group.lab11b_dr.name
  tags                = local.default_tags
}

resource "azurerm_subnet" "lab11b_dr" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.lab11b_dr.name
  virtual_network_name = azurerm_virtual_network.lab11b_dr.name
  address_prefixes     = ["10.12.1.0/24"]
}

# =============================================================================
# DR Load Balancer (Japan West) — Empty backend pool, used after failover
# =============================================================================
resource "azurerm_public_ip" "lab11b_dr" {
  name                = "${local.lab11b_name}-dr-pip-${local.random_str}"
  location            = azurerm_resource_group.lab11b_dr.location
  resource_group_name = azurerm_resource_group.lab11b_dr.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${local.lab11b_name}-dr-pip-${local.random_str}"
  tags                = local.default_tags
}

resource "azurerm_lb" "lab11b_dr" {
  name                = "${local.lab11b_name}-dr-lb-${local.random_str}"
  location            = azurerm_resource_group.lab11b_dr.location
  resource_group_name = azurerm_resource_group.lab11b_dr.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lab11b_dr.id
  }
  tags = local.default_tags
}

resource "azurerm_lb_backend_address_pool" "lab11b_dr" {
  loadbalancer_id = azurerm_lb.lab11b_dr.id
  name            = "BackendPool"
}

resource "azurerm_lb_probe" "lab11b_dr" {
  loadbalancer_id     = azurerm_lb.lab11b_dr.id
  name                = "probe"
  port                = 80
  interval_in_seconds = 5
}

resource "azurerm_lb_rule" "lab11b_dr" {
  loadbalancer_id                = azurerm_lb.lab11b_dr.id
  name                           = "rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lab11b_dr.id]
  probe_id                       = azurerm_lb_probe.lab11b_dr.id
  disable_outbound_snat          = false
}

# =============================================================================
# Cache Storage Account (Japan East) — Required by ASR replication
# =============================================================================
resource "azurerm_storage_account" "lab11b_cache" {
  name                     = "${local.lab11b_name}cache${local.random_str}"
  location                 = azurerm_resource_group.az104.location
  resource_group_name      = azurerm_resource_group.az104.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.default_tags
}

# =============================================================================
# Recovery Services Vault (Japan West)
# =============================================================================
resource "azurerm_recovery_services_vault" "lab11b" {
  name                = "${local.lab11b_name}-vault-${local.random_str}"
  location            = azurerm_resource_group.lab11b_dr.location
  resource_group_name = azurerm_resource_group.lab11b_dr.name
  sku = "Standard"

  soft_delete_enabled = false

  tags = local.default_tags
}

# =============================================================================
# ASR Fabrics (Primary & Recovery)
# =============================================================================
resource "azurerm_site_recovery_fabric" "lab11b_primary" {
  name                = "primary-fabric"
  resource_group_name = azurerm_resource_group.lab11b_dr.name
  recovery_vault_name = azurerm_recovery_services_vault.lab11b.name
  location            = azurerm_resource_group.az104.location
}

resource "azurerm_site_recovery_fabric" "lab11b_recovery" {
  name                = "recovery-fabric"
  resource_group_name = azurerm_resource_group.lab11b_dr.name
  recovery_vault_name = azurerm_recovery_services_vault.lab11b.name
  location            = azurerm_resource_group.lab11b_dr.location

  depends_on = [azurerm_site_recovery_fabric.lab11b_primary]
}

# =============================================================================
# ASR Protection Containers
# =============================================================================
resource "azurerm_site_recovery_protection_container" "lab11b_primary" {
  name                 = "primary-protection-container"
  resource_group_name  = azurerm_resource_group.lab11b_dr.name
  recovery_vault_name  = azurerm_recovery_services_vault.lab11b.name
  recovery_fabric_name = azurerm_site_recovery_fabric.lab11b_primary.name
}

resource "azurerm_site_recovery_protection_container" "lab11b_recovery" {
  name                 = "recovery-protection-container"
  resource_group_name  = azurerm_resource_group.lab11b_dr.name
  recovery_vault_name  = azurerm_recovery_services_vault.lab11b.name
  recovery_fabric_name = azurerm_site_recovery_fabric.lab11b_recovery.name
}

# =============================================================================
# ASR Replication Policy
# =============================================================================
resource "azurerm_site_recovery_replication_policy" "lab11b" {
  name                                                 = "${local.lab11b_name}-replication-policy"
  resource_group_name                                  = azurerm_resource_group.lab11b_dr.name
  recovery_vault_name                                  = azurerm_recovery_services_vault.lab11b.name
  recovery_point_retention_in_minutes                  = 1440
  application_consistent_snapshot_frequency_in_minutes = 240
}

# =============================================================================
# ASR Container Mapping (Primary -> Recovery)
# =============================================================================
resource "azurerm_site_recovery_protection_container_mapping" "lab11b" {
  name                                      = "primary-to-recovery-mapping"
  resource_group_name                       = azurerm_resource_group.lab11b_dr.name
  recovery_vault_name                       = azurerm_recovery_services_vault.lab11b.name
  recovery_fabric_name                      = azurerm_site_recovery_fabric.lab11b_primary.name
  recovery_source_protection_container_name = azurerm_site_recovery_protection_container.lab11b_primary.name
  recovery_target_protection_container_id   = azurerm_site_recovery_protection_container.lab11b_recovery.id
  recovery_replication_policy_id            = azurerm_site_recovery_replication_policy.lab11b.id
}

# =============================================================================
# ASR Network Mapping (Primary VNet -> DR VNet)
# =============================================================================
resource "azurerm_site_recovery_network_mapping" "lab11b" {
  name                        = "primary-to-recovery-network-mapping"
  resource_group_name         = azurerm_resource_group.lab11b_dr.name
  recovery_vault_name         = azurerm_recovery_services_vault.lab11b.name
  source_recovery_fabric_name = azurerm_site_recovery_fabric.lab11b_primary.name
  target_recovery_fabric_name = azurerm_site_recovery_fabric.lab11b_recovery.name
  source_network_id           = azurerm_virtual_network.lab11b.id
  target_network_id           = azurerm_virtual_network.lab11b_dr.id
}

# =============================================================================
# Data sources for managed disk IDs (needed by ASR replication)
# =============================================================================
data "azurerm_managed_disk" "lab11b01_osdisk" {
  name                = "${local.lab11b_name}-osdisk-01-${local.random_str}"
  resource_group_name = azurerm_resource_group.az104.name

  depends_on = [azurerm_windows_virtual_machine.lab11b01]
}

data "azurerm_managed_disk" "lab11b02_osdisk" {
  name                = "${local.lab11b_name}-osdisk-02-${local.random_str}"
  resource_group_name = azurerm_resource_group.az104.name

  depends_on = [azurerm_windows_virtual_machine.lab11b02]
}

# =============================================================================
# ASR Replicated VMs
# =============================================================================
resource "azurerm_site_recovery_replicated_vm" "lab11b01" {
  name                                      = "${local.lab11b_name}-vm01-replication"
  resource_group_name                       = azurerm_resource_group.lab11b_dr.name
  recovery_vault_name                       = azurerm_recovery_services_vault.lab11b.name
  source_recovery_fabric_name               = azurerm_site_recovery_fabric.lab11b_primary.name
  source_vm_id                              = azurerm_windows_virtual_machine.lab11b01.id
  recovery_replication_policy_id            = azurerm_site_recovery_replication_policy.lab11b.id
  source_recovery_protection_container_name = azurerm_site_recovery_protection_container.lab11b_primary.name

  target_resource_group_id                = azurerm_resource_group.lab11b_dr.id
  target_recovery_fabric_id               = azurerm_site_recovery_fabric.lab11b_recovery.id
  target_recovery_protection_container_id = azurerm_site_recovery_protection_container.lab11b_recovery.id

  managed_disk {
    disk_id                    = lower(data.azurerm_managed_disk.lab11b01_osdisk.id)
    staging_storage_account_id = azurerm_storage_account.lab11b_cache.id
    target_resource_group_id   = azurerm_resource_group.lab11b_dr.id
    target_disk_type           = "Premium_LRS"
    target_replica_disk_type   = "Premium_LRS"
  }

  network_interface {
    source_network_interface_id                    = azurerm_network_interface.lab11b01.id
    target_subnet_name                             = azurerm_subnet.lab11b_dr.name
    recovery_load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.lab11b_dr.id]
  }

  lifecycle {
    ignore_changes = [
      managed_disk,
      network_interface,
      target_virtual_machine_size,
    ]
  }

  depends_on = [
    azurerm_site_recovery_protection_container_mapping.lab11b,
    azurerm_site_recovery_network_mapping.lab11b,
    azurerm_virtual_machine_extension.lab11b01script,
    azurerm_virtual_machine_extension.lab11b01ama,
    azurerm_virtual_machine_extension.lab11b01da,
  ]
}

resource "azurerm_site_recovery_replicated_vm" "lab11b02" {
  name                                      = "${local.lab11b_name}-vm02-replication"
  resource_group_name                       = azurerm_resource_group.lab11b_dr.name
  recovery_vault_name                       = azurerm_recovery_services_vault.lab11b.name
  source_recovery_fabric_name               = azurerm_site_recovery_fabric.lab11b_primary.name
  source_vm_id                              = azurerm_windows_virtual_machine.lab11b02.id
  recovery_replication_policy_id            = azurerm_site_recovery_replication_policy.lab11b.id
  source_recovery_protection_container_name = azurerm_site_recovery_protection_container.lab11b_primary.name

  target_resource_group_id                = azurerm_resource_group.lab11b_dr.id
  target_recovery_fabric_id               = azurerm_site_recovery_fabric.lab11b_recovery.id
  target_recovery_protection_container_id = azurerm_site_recovery_protection_container.lab11b_recovery.id

  managed_disk {
    disk_id                    = lower(data.azurerm_managed_disk.lab11b02_osdisk.id)
    staging_storage_account_id = azurerm_storage_account.lab11b_cache.id
    target_resource_group_id   = azurerm_resource_group.lab11b_dr.id
    target_disk_type           = "Premium_LRS"
    target_replica_disk_type   = "Premium_LRS"
  }

  network_interface {
    source_network_interface_id                    = azurerm_network_interface.lab11b02.id
    target_subnet_name                             = azurerm_subnet.lab11b_dr.name
    recovery_load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.lab11b_dr.id]
  }

  lifecycle {
    ignore_changes = [
      managed_disk,
      network_interface,
      target_virtual_machine_size,
    ]
  }

  depends_on = [
    azurerm_site_recovery_protection_container_mapping.lab11b,
    azurerm_site_recovery_network_mapping.lab11b,
    azurerm_virtual_machine_extension.lab11b02script,
    azurerm_virtual_machine_extension.lab11b02ama,
    azurerm_virtual_machine_extension.lab11b02da,
    azurerm_site_recovery_replicated_vm.lab11b01,
  ]
}

# =============================================================================
# Recovery Plan with manual action for DR LB binding
# =============================================================================
resource "azurerm_site_recovery_replication_recovery_plan" "lab11b" {
  name                      = "${local.lab11b_name}-recovery-plan"
  recovery_vault_id         = azurerm_recovery_services_vault.lab11b.id
  source_recovery_fabric_id = azurerm_site_recovery_fabric.lab11b_primary.id
  target_recovery_fabric_id = azurerm_site_recovery_fabric.lab11b_recovery.id

  boot_recovery_group {
    replicated_protected_items = [
      azurerm_site_recovery_replicated_vm.lab11b01.id,
      azurerm_site_recovery_replicated_vm.lab11b02.id,
    ]

    post_action {
      name                      = "Verify-DR-LB-Access"
      type                      = "ManualActionDetails"
      fail_over_directions      = ["PrimaryToRecovery"]
      fail_over_types           = ["TestFailover", "UnplannedFailover"]
      manual_action_instruction = "VMs are automatically added to DR LB backend pool. Verify IIS is accessible via DR LB public IP: http://${local.lab11b_name}-dr-pip-${local.random_str}.japanwest.cloudapp.azure.com"
    }
  }

  failover_recovery_group {}

  shutdown_recovery_group {}
}
