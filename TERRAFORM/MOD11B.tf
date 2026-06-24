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

  lifecycle {
    ignore_changes = [ip_tags]
  }
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

# DR 子網路 NSG — 允許來自 Internet 的 HTTP(80),讓 public LB 能對外服務失容後的 VM
resource "azurerm_network_security_group" "lab11b_dr" {
  name                = "${local.lab11b_name}-dr-nsg-${local.random_str}"
  location            = azurerm_resource_group.lab11b_dr.location
  resource_group_name = azurerm_resource_group.lab11b_dr.name
  tags                = local.default_tags
}

resource "azurerm_network_security_rule" "lab11b_dr_http" {
  name                        = "HTTP"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "*"
  destination_port_range      = "80"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.lab11b_dr.name
  network_security_group_name = azurerm_network_security_group.lab11b_dr.name
}

resource "azurerm_subnet_network_security_group_association" "lab11b_dr" {
  subnet_id                 = azurerm_subnet.lab11b_dr.id
  network_security_group_id = azurerm_network_security_group.lab11b_dr.id
}

# =============================================================================
# DR Load Balancer (Japan West) — Public (對外服務) Load Balancer
# 失容後由 Recovery Plan 的 Automation Runbook (azurerm_automation_runbook.lab11b)
# 自動把複寫 VM 的 NIC 加入此後端集區。ASR 內建的
# recovery_load_balancer_backend_address_pool_ids 只支援 internal LB(否則回報錯誤
# 150276),改用 runbook 後即可使用 public LB 對外服務,並可在前面掛 Traffic Manager。
# 注意:執行 Test Failover 時請選 DR VNet 作為測試網路,失容 VM 才會與此 LB 同 VNet。
# =============================================================================
resource "azurerm_public_ip" "lab11b_dr" {
  name                = "${local.lab11b_name}-dr-pip-${local.random_str}"
  location            = azurerm_resource_group.lab11b_dr.location
  resource_group_name = azurerm_resource_group.lab11b_dr.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${local.lab11b_name}-dr-pip-${local.random_str}"
  tags                = local.default_tags

  lifecycle {
    ignore_changes = [ip_tags]
  }
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
  sku                 = "Standard"

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
    source_network_interface_id = azurerm_network_interface.lab11b01.id
    target_subnet_name          = azurerm_subnet.lab11b_dr.name
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
    source_network_interface_id = azurerm_network_interface.lab11b02.id
    target_subnet_name          = azurerm_subnet.lab11b_dr.name
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
# Azure Automation — 失容後自動把 VM 加入 DR public LB 後端集區的 Runbook
# Recovery Plan 的 post-action 會在 Test/Unplanned Failover 後執行此 runbook,
# runbook 讀取 Recovery Plan Context 取得失容 VM,把其 NIC 加入 public LB 後端集區
# (public LB 無法使用 ASR 內建 recovery_load_balancer 設定,故改用 runbook)。
# 需求:Automation Account 與 Recovery Services Vault 同訂閱;受控識別碼需有權限
# 修改 DR 資源群組內的 NIC / LB(此處指派 Contributor)。
# =============================================================================
resource "azurerm_automation_account" "lab11b" {
  name                = "${local.lab11b_name}-automation-${local.random_str}"
  location            = azurerm_resource_group.lab11b_dr.location
  resource_group_name = azurerm_resource_group.lab11b_dr.name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }

  tags = local.default_tags
}

# Runbook 受控識別碼權限 — 可在 DR 資源群組修改 NIC 與 Load Balancer
# Runbook 受控識別碼權限(最小權限):Network Contributor 可改 NIC 並 join LB 後端集區,
# Reader 提供 Get-AzVM 所需的 Microsoft.Compute/.../read。skip_service_principal_aad_check
# 避免新建識別碼因 AAD 複寫延遲而出現 PrincipalNotFound。
resource "azurerm_role_assignment" "lab11b_automation_network" {
  scope                            = azurerm_resource_group.lab11b_dr.id
  role_definition_name             = "Network Contributor"
  principal_id                     = azurerm_automation_account.lab11b.identity[0].principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "lab11b_automation_reader" {
  scope                            = azurerm_resource_group.lab11b_dr.id
  role_definition_name             = "Reader"
  principal_id                     = azurerm_automation_account.lab11b.identity[0].principal_id
  skip_service_principal_aad_check = true
}

# 把 DR public LB 後端集區的資源 ID 存成 Automation 變數,供 runbook 讀取
resource "azurerm_automation_variable_string" "lab11b_dr_backend_pool" {
  name                    = "DrBackendPoolId"
  resource_group_name     = azurerm_resource_group.lab11b_dr.name
  automation_account_name = azurerm_automation_account.lab11b.name
  value                   = azurerm_lb_backend_address_pool.lab11b_dr.id
}

resource "azurerm_automation_runbook" "lab11b" {
  name                    = "${local.lab11b_name}-add-to-lb"
  location                = azurerm_resource_group.lab11b_dr.location
  resource_group_name     = azurerm_resource_group.lab11b_dr.name
  automation_account_name = azurerm_automation_account.lab11b.name
  log_verbose             = false
  log_progress            = true
  runbook_type            = "PowerShell"
  description             = "ASR post-failover: 把失容後的 VM NIC 加入 DR public LB 後端集區"

  content = <<-CONTENT
    param([parameter(Mandatory = $false)][Object]$RecoveryPlanContext)

    $ErrorActionPreference = "Stop"

    Write-Output "Authenticating with the Automation account managed identity..."
    Disable-AzContextAutosave -Scope Process | Out-Null
    Connect-AzAccount -Identity | Out-Null

    $backendPoolId = Get-AutomationVariable -Name "DrBackendPoolId"
    Write-Output ("Target backend pool: " + $backendPoolId)

    $parts = $backendPoolId.Trim("/").Split("/")
    $lbResourceGroup = $parts[3]
    $lbName = $parts[7]
    $poolName = $parts[9]

    $lb = Get-AzLoadBalancer -ResourceGroupName $lbResourceGroup -Name $lbName
    $backendPool = Get-AzLoadBalancerBackendAddressPoolConfig -Name $poolName -LoadBalancer $lb

    if ($null -eq $RecoveryPlanContext) {
        Write-Output "No RecoveryPlanContext supplied (manual run); nothing to do."
        return
    }

    Write-Output ("Failover type: " + $RecoveryPlanContext.FailoverType)
    $vmKeys = $RecoveryPlanContext.VmMap.PSObject.Properties.Name

    foreach ($key in $vmKeys) {
        $vm = $RecoveryPlanContext.VmMap.$key
        $rg = $vm.ResourceGroupName
        $vmName = $vm.RoleName
        if ([string]::IsNullOrEmpty($rg) -or [string]::IsNullOrEmpty($vmName)) { continue }
        Write-Output ("Processing failed-over VM: " + $vmName + " (RG: " + $rg + ")")

        # Test Failover 會建立帶 "-test" 後綴的 VM(正式 failover 維持原名),兩者都要涵蓋,
        # 否則 Test Failover 時用原名找不到 VM 會中斷 runbook,NIC 就不會被加入後端集區。
        $azVm = Get-AzVM -ResourceGroupName $rg -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq $vmName -or $_.Name -eq ($vmName + "-test") } |
            Select-Object -First 1
        if ($null -eq $azVm) {
            Write-Output ("  找不到 role " + $vmName + " 對應的 VM(已試 '" + $vmName + "' 與 '" + $vmName + "-test'),略過。")
            continue
        }
        foreach ($nicRef in $azVm.NetworkProfile.NetworkInterfaces) {
            $nic = Get-AzNetworkInterface -ResourceId $nicRef.Id
            $ipcfg = $nic.IpConfigurations | Where-Object { $_.Primary } | Select-Object -First 1
            if ($null -eq $ipcfg) { $ipcfg = $nic.IpConfigurations[0] }
            if ($null -eq $ipcfg.LoadBalancerBackendAddressPools) {
                $ipcfg.LoadBalancerBackendAddressPools = New-Object "System.Collections.Generic.List[Microsoft.Azure.Commands.Network.Models.PSBackendAddressPool]"
            }
            if ($ipcfg.LoadBalancerBackendAddressPools.Id -contains $backendPool.Id) {
                Write-Output ("  NIC " + $nic.Name + " already in pool; skipping.")
                continue
            }
            $ipcfg.LoadBalancerBackendAddressPools.Add($backendPool)
            Set-AzNetworkInterface -NetworkInterface $nic | Out-Null
            Write-Output ("  Added NIC " + $nic.Name + " to backend pool " + $poolName + ".")
        }
    }

    Write-Output "Backend pool association complete."
  CONTENT

  tags = local.default_tags
}

# =============================================================================
# Recovery Plan — Test/Unplanned Failover 後自動把 VM 加入 DR public LB
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
      name                 = "Add-VMs-To-DR-Public-LB"
      type                 = "AutomationRunbookActionDetails"
      fail_over_directions = ["PrimaryToRecovery"]
      fail_over_types      = ["TestFailover", "UnplannedFailover"]
      runbook_id           = azurerm_automation_runbook.lab11b.id
      fabric_location      = "Recovery"
    }

    post_action {
      name                      = "Verify-via-Traffic-Manager"
      type                      = "ManualActionDetails"
      fail_over_directions      = ["PrimaryToRecovery"]
      fail_over_types           = ["TestFailover", "UnplannedFailover"]
      manual_action_instruction = "驗證:(1) 用瀏覽器存取「DR public LB 的 FQDN」確認失容後 IIS 可對外服務(runbook 已把 VM 加入後端集區)。(2) Traffic Manager 為 Priority 路由,primary 健康時一律導向 primary;要示範 TM 自動切換到 DR,需先讓 primary 不健康(停掉 primary VM/IIS 或停用 primary 端點)。注意:Test Failover 請選 DR VNet (${local.lab11b_name}-dr-vnet) 作為測試網路,VM 才會與 public LB 同屬一個 VNet。"
    }
  }

  failover_recovery_group {}

  shutdown_recovery_group {}
}

# =============================================================================
# Traffic Manager — 對外入口,Priority 路由:Primary(Japan East)優先、DR(Japan West)備援
# 平時導向 primary public LB;primary 失效時自動切到 DR public LB,模擬真實 DR 架構。
# =============================================================================
resource "azurerm_traffic_manager_profile" "lab11b" {
  name                   = "${local.lab11b_name}-tm-${var.group_postfix}-${random_string.rid.result}"
  resource_group_name    = azurerm_resource_group.az104.name
  traffic_routing_method = "Priority"

  dns_config {
    relative_name = "${local.lab11b_name}-tm-${var.group_postfix}-${random_string.rid.result}"
    ttl           = 30
  }

  monitor_config {
    protocol                     = "HTTP"
    port                         = 80
    path                         = "/"
    interval_in_seconds          = 30
    timeout_in_seconds           = 10
    tolerated_number_of_failures = 3
  }

  tags = local.default_tags
}

resource "azurerm_traffic_manager_azure_endpoint" "lab11b_primary" {
  name               = "primary-japaneast"
  profile_id         = azurerm_traffic_manager_profile.lab11b.id
  priority           = 1
  target_resource_id = azurerm_public_ip.lab11b.id
}

resource "azurerm_traffic_manager_azure_endpoint" "lab11b_dr" {
  name               = "dr-japanwest"
  profile_id         = azurerm_traffic_manager_profile.lab11b.id
  priority           = 2
  target_resource_id = azurerm_public_ip.lab11b_dr.id
}

resource "azurerm_monitor_diagnostic_setting" "lab11b_recovery_services_vault" {
  name                       = "${azurerm_recovery_services_vault.lab11b.name}-diag"
  target_resource_id         = azurerm_recovery_services_vault.lab11b.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_log {
    category = "CoreAzureBackup"
  }

  enabled_log {
    category = "AddonAzureBackupJobs"
  }

  enabled_log {
    category = "AddonAzureBackupAlerts"
  }

  enabled_log {
    category = "AddonAzureBackupPolicy"
  }

  enabled_log {
    category = "AddonAzureBackupStorage"
  }

  enabled_log {
    category = "AddonAzureBackupProtectedInstance"
  }

  enabled_log {
    category = "AzureSiteRecoveryJobs"
  }

  enabled_log {
    category = "AzureSiteRecoveryEvents"
  }

  enabled_log {
    category = "AzureSiteRecoveryReplicatedItems"
  }

  enabled_log {
    category = "AzureSiteRecoveryReplicationStats"
  }

  enabled_log {
    category = "AzureSiteRecoveryRecoveryPoints"
  }

  enabled_log {
    category = "AzureSiteRecoveryReplicationDataUploadRate"
  }

  enabled_log {
    category = "AzureSiteRecoveryProtectedDiskDataChurn"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab11b_nsg" {
  name                       = "${azurerm_network_security_group.lab11b.name}-diag"
  target_resource_id         = azurerm_network_security_group.lab11b.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab11b_lb" {
  name                       = "${azurerm_lb.lab11b.name}-diag"
  target_resource_id         = azurerm_lb.lab11b.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_log {
    category = "LoadBalancerHealthEvent"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab11b_dr_lb" {
  name                       = "${azurerm_lb.lab11b_dr.name}-diag"
  target_resource_id         = azurerm_lb.lab11b_dr.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_log {
    category = "LoadBalancerHealthEvent"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab11b_public_ip" {
  name                       = "${azurerm_public_ip.lab11b.name}-diag"
  target_resource_id         = azurerm_public_ip.lab11b.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab11b_dr_public_ip" {
  name                       = "${azurerm_public_ip.lab11b_dr.name}-diag"
  target_resource_id         = azurerm_public_ip.lab11b_dr.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab11b_cache_blob" {
  name                       = "${azurerm_storage_account.lab11b_cache.name}-blob-diag"
  target_resource_id         = "${azurerm_storage_account.lab11b_cache.id}/blobServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  enabled_metric {
    category = "Transaction"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab11b_cache_file" {
  name                       = "${azurerm_storage_account.lab11b_cache.name}-file-diag"
  target_resource_id         = "${azurerm_storage_account.lab11b_cache.id}/fileServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  enabled_metric {
    category = "Transaction"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab11b_cache_queue" {
  name                       = "${azurerm_storage_account.lab11b_cache.name}-queue-diag"
  target_resource_id         = "${azurerm_storage_account.lab11b_cache.id}/queueServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  enabled_metric {
    category = "Transaction"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab11b_cache_table" {
  name                       = "${azurerm_storage_account.lab11b_cache.name}-table-diag"
  target_resource_id         = "${azurerm_storage_account.lab11b_cache.id}/tableServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  enabled_metric {
    category = "Transaction"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab11b_virtual_network" {
  name                       = "${azurerm_virtual_network.lab11b.name}-diag"
  target_resource_id         = azurerm_virtual_network.lab11b.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab11b_dr_virtual_network" {
  name                       = "${azurerm_virtual_network.lab11b_dr.name}-diag"
  target_resource_id         = azurerm_virtual_network.lab11b_dr.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_metric {
    category = "AllMetrics"
  }
}
