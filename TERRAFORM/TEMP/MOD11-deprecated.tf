## LAB-11-ALERT
# Create virtual network
resource "azurerm_virtual_network" "lab11" {
  name                = local.lab11_name_with_postfix
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  tags = {
    environment = local.group_name
  }
}

# Create subnet
resource "azurerm_subnet" "lab11" {
  name                 = local.lab11_name_with_postfix
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab11.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "lab11" {
  name                = local.lab11_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  sku                 = "Standard"
  domain_name_label   = lower(local.lab11_name_with_postfix)

  tags = {
    environment = local.group_name
  }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "lab11" {
  name                = local.lab11_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_network_security_rule" "lab1101" {
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
  network_security_group_name = azurerm_network_security_group.lab11.name
}

resource "azurerm_network_security_rule" "lab1102" {
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
  network_security_group_name = azurerm_network_security_group.lab11.name
}

# Create network interface
resource "azurerm_network_interface" "lab11" {
  name                = local.lab11_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = local.lab11_name_with_postfix
    subnet_id                     = azurerm_subnet.lab11.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.lab11.id
  }

  tags = {
    environment = local.group_name
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "lab11" {
  network_interface_id      = azurerm_network_interface.lab11.id
  network_security_group_id = azurerm_network_security_group.lab11.id
}

# Create virtual machine
resource "azurerm_windows_virtual_machine" "lab11" {
  name                  = local.lab11_name_with_postfix
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab11.id]
  size                  = local.vm_size

  os_disk {
    name                 = local.lab11_name_with_postfix
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  computer_name  = local.lab11_name
  admin_username = local.user_name
  admin_password = local.user_passowrd

  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_machine_extension" "lab11ama" {
  name                       = "AzureMonitorWindowsAgent"
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab11.id

  tags = {
    environment = local.group_name
  }
}

resource "azurerm_virtual_machine_extension" "lab11da" {
  name                       = "DependencyAgentWindows"
  publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                       = "DependencyAgentWindows"
  type_handler_version       = "9.10"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.lab11.id

  settings = jsonencode({
    enableAMA = "true"
  })

  tags = {
    environment = local.group_name
  }

  depends_on = [azurerm_virtual_machine_extension.lab11ama]
}

resource "azurerm_monitor_data_collection_rule_association" "lab11" {
  name                    = "lab11-dcra"
  target_resource_id      = azurerm_windows_virtual_machine.lab11.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vminsights.id
  description             = "VM Insights DCR association for lab11"
}
