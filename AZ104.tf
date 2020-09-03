provider "azurerm" {
  # The "feature" block is required for AzureRM provider 2.x. 
  # If you are using version 1.x, the "features" block is not allowed.
  version = "~>2.0"
  features {}
}

locals {
  group_name               = "AZ10404"
  lab01_name               = "LAB01VMWEB"
  lab02_name               = "LAB02CI"
  lab03_name               = "LAB03VM"
  lab04_name               = "LAB04BLOB"
  lab05_name               = "LAB05VPN"
  lab06_name               = "LAB06IOTHUB"
  lab07_name               = "LAB07FUNCTION"
  lab08_name               = "LAB08WEBAPP"
  lab11_name               = "lab11"
  lab13_name               = "LAB13KEYVALUT"
  lab14_name               = "LAB14COSMOS"
  lab09a_name              = "lab09A"
  lab09b_name              = "lab09B"
  lab09c_name              = "lab09C"
  lab09d_name              = "lab09D"
  lab01_name_with_postfix  = "${local.lab01_name}${random_string.rid.result}"
  lab02_name_with_postfix  = "${local.lab02_name}${random_string.rid.result}"
  lab03_name_with_postfix  = "${local.lab03_name}${random_string.rid.result}"
  lab04_name_with_postfix  = "${local.lab04_name}${random_string.rid.result}"
  lab05_name_with_postfix  = "${local.lab05_name}${random_string.rid.result}"
  lab06_name_with_postfix  = "${local.lab06_name}${random_string.rid.result}"
  lab07_name_with_postfix  = "${local.lab07_name}${random_string.rid.result}"
  lab08_name_with_postfix  = "${local.lab08_name}${random_string.rid.result}"
  lab11_name_with_postfix  = lower("${local.lab11_name}${random_string.rid.result}")
  lab13_name_with_postfix  = "${local.lab13_name}${random_string.rid.result}"
  lab14_name_with_postfix  = "${local.lab14_name}${random_string.rid.result}"
  lab09a_name_with_postfix = lower("${local.lab09a_name}${random_string.rid.result}")
  lab09b_name_with_postfix = lower("${local.lab09b_name}${random_string.rid.result}")
  lab09c_name_with_postfix = lower("${local.lab09c_name}${random_string.rid.result}")
  lab09d_name_with_postfix = lower("${local.lab09d_name}${random_string.rid.result}")
  user_name                = "demouser"
  user_passowrd            = "Azuredemo@2020"
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

data "azurerm_client_config" "current" {}

resource "random_string" "rid" {
  length  = 6
  special = false
}

resource "random_integer" "rint" {
  min = 10000
  max = 99999
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "az104" {
  name     = local.group_name
  location = "southeastasia"

  tags = {
    environment = local.group_name
  }
}

## LAB-09-A-WEBAPP
resource "azurerm_app_service_plan" "lab09a" {
  name                = local.lab09a_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_app_service" "lab09a" {
  name                = local.lab09a_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  app_service_plan_id = azurerm_app_service_plan.lab09a.id

  site_config {
    linux_fx_version = "DOTNETCORE|3.1"
  }
}

## LAB-09-B-INSIGHT
resource "azurerm_application_insights" "lab09b" {
  name                = local.lab09b_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  application_type    = "web"

  tags = {
    environment = local.group_name
  }
}

## LAB-9-C-ACI
# Create Container Instance
resource "azurerm_container_group" "lab09c" {
  name                = local.lab09c_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  ip_address_type     = "public"
  dns_name_label      = local.lab09c_name_with_postfix
  os_type             = "Linux"

  container {
    name   = "hello-world"
    image  = "microsoft/aci-helloworld:latest"
    cpu    = "2"
    memory = "4"

    ports {
      port     = 80
      protocol = "TCP"
    }
  }

  tags = {
    environment = local.group_name
  }
}

## LAB-11-ALERT
# Create virtual network
resource "azurerm_virtual_network" "lab11" {
  name                = "${local.lab11_name_with_postfix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  tags = {
    environment = local.group_name
  }
}

# Create subnet
resource "azurerm_subnet" "lab11" {
  name                 = "${local.lab11_name_with_postfix}-subnet"
  resource_group_name  = azurerm_resource_group.az104.name
  virtual_network_name = azurerm_virtual_network.lab11.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "lab11" {
  name                = "${local.lab11_name_with_postfix}-publicip"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  allocation_method   = "Dynamic"
  domain_name_label   = lower(local.lab11_name_with_postfix)

  tags = {
    environment = local.group_name
  }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "lab11" {
  name                = "${local.lab11_name_with_postfix}-nsg01"
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
  name                = "${local.lab11_name_with_postfix}-NIC"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name

  ip_configuration {
    name                          = "${local.lab11_name_with_postfix}-NicConfig"
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
  name                  = lower(replace(local.lab11_name_with_postfix, "-", ""))
  location              = azurerm_resource_group.az104.location
  resource_group_name   = azurerm_resource_group.az104.name
  network_interface_ids = [azurerm_network_interface.lab11.id]
  size                  = "Standard_B4ms"

  os_disk {
    name                 = "${lower(replace(local.lab11_name_with_postfix, "-", ""))}OsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  computer_name  = local.lab11_name
  admin_username = local.user_name
  admin_password = local.user_passowrd

  tags = {
    environment = local.group_name
  }
}