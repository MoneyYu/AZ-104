## LAB-8B-VMSS
# This module creates a Virtual Machine Scale Set that uses the Bastion from MOD08.tf

# Create a separate subnet for VMSS in the same VNet
resource "azurerm_subnet" "lab08vmss" {
  name                 = "vmss-subnet"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab08.name
  address_prefixes     = ["10.10.3.0/24"]
}

# VMSS 子網路專屬 NSG:與 MOD08 的 default 子網路分開,示範不同子網路套用不同 NSG。
# 只開放 public Load Balancer 服務所需的 80 埠,不繼承 default 子網路的 RDP 規則。
resource "azurerm_network_security_group" "lab08vmss" {
  name                = "${local.lab08_name}b-vmss-nsg-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  tags                = local.default_tags
}

# 公開 Load Balancer 的入站流量會保留原始用戶端來源 IP(屬 Internet),
# 不會命中 AllowAzureLoadBalancerInBound 服務標籤,因此必須明確放行 80 埠,
# 否則會被預設規則 DenyAllInBound 擋下,VMSS 網頁示範將無法連線。
resource "azurerm_network_security_rule" "lab08vmss_http" {
  name                        = "AllowHTTP"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "*"
  destination_port_range      = "80"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.az104.name
  network_security_group_name = azurerm_network_security_group.lab08vmss.name
}

# Subnet-level NSG association for VMSS subnet (dedicated NSG)
resource "azurerm_subnet_network_security_group_association" "lab08vmss" {
  subnet_id                 = azurerm_subnet.lab08vmss.id
  network_security_group_id = azurerm_network_security_group.lab08vmss.id
}

# Create a Load Balancer for VMSS
resource "azurerm_public_ip" "lab08vmss" {
  name                = "${local.lab08_name}b-lb-pip-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.default_tags

  lifecycle {
    ignore_changes = [ip_tags]
  }
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
  name                 = "${local.lab08_name}b-vmss-${local.random_str}"
  location             = azurerm_resource_group.az104.location
  resource_group_name  = azurerm_resource_group.az104.name
  sku                  = local.vm_size
  instances            = 2
  admin_username       = local.user_name
  admin_password       = local.user_password
  computer_name_prefix = "vmss"

  # 保留給 Lab 08 示範：映像或設定更新需由講師手動套用至執行個體。
  upgrade_mode = "Manual"

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

  identity {
    type = "SystemAssigned"
  }

  # 必要 extension 直接納入 VMSS model，確保全新建立的執行個體設定一致。
  extension {
    name                       = "AzureMonitorWindowsAgent"
    publisher                  = "Microsoft.Azure.Monitor"
    type                       = "AzureMonitorWindowsAgent"
    type_handler_version       = "1.0"
    automatic_upgrade_enabled  = true
    auto_upgrade_minor_version = true
  }

  extension {
    name                       = "${local.lab08_name}b-vmss-iis-${local.random_str}"
    publisher                  = "Microsoft.Compute"
    type                       = "CustomScriptExtension"
    type_handler_version       = "1.10"
    auto_upgrade_minor_version = true

    settings = jsonencode({
      commandToExecute = "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from VMSS instance: ' + $env:computername)"
    })
  }

  extension {
    name                       = "${local.lab08_name}b-vmss-aad-${local.random_str}"
    publisher                  = "Microsoft.Azure.ActiveDirectory"
    type                       = "AADLoginForWindows"
    type_handler_version       = "1.0"
    auto_upgrade_minor_version = true
  }

  tags = local.default_tags
}

# VMSS 目前僅支援 log-based VM Insights，不支援新的 OTel metrics 體驗。
resource "azurerm_monitor_data_collection_rule_association" "lab08vmss" {
  name                    = "lab08vmss-dcra"
  target_resource_id      = azurerm_windows_virtual_machine_scale_set.lab08vmss.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vminsights.id
  description             = "VM Insights DCR association for lab08vmss"
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

resource "azurerm_monitor_diagnostic_setting" "lab08vmss_lb" {
  name                       = "lab08vmss-diag"
  target_resource_id         = azurerm_lb.lab08vmss.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_log {
    category = "LoadBalancerHealthEvent"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "lab08vmss_public_ip" {
  name                       = "lab08vmss-diag"
  target_resource_id         = azurerm_public_ip.lab08vmss.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_metric {
    category = "AllMetrics"
  }
}

# vmss-subnet 改用專屬 NSG 後，需自行設定診斷；否則該子網路的 NSG 事件
# 會隨著脫離 lab08-nsg 而不再送進 Log Analytics。類別與 MOD08 的兩個 NSG 一致。
resource "azurerm_monitor_diagnostic_setting" "lab08vmss_nsg" {
  name                       = "lab08vmss-diag"
  target_resource_id         = azurerm_network_security_group.lab08vmss.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vminsights.id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}
