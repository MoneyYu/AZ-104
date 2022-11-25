terraform {
  required_version = ">=0.12"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  group_name               = "AZ104-${formatdate("MMDDHHmm", timestamp())}"
  location                 = "japaneast"
  lab01_name               = "lab01"
  lab02_name               = "lab02"
  lab03_name               = "lab03"
  lab04_name               = "lab04"
  lab05a_name              = "lab05a"
  lab05b_name              = "lab05b"
  lab06a_name              = "lab06a"
  lab06b_name              = "lab06b"
  lab06c_name              = "lab06c"
  lab06d_name              = "lab06c"
  lab07_name               = "lab07"
  lab08_name               = "lab08"
  lab09a_name              = "lab09a"
  lab09b_name              = "lab09b"
  lab09c_name              = "lab09c"
  lab09d_name              = "lab09d"
  lab10_name               = "lab10"
  lab11_name               = "lab11"
  lab01_name_with_postfix  = lower("${local.lab01_name}${random_string.rid.result}")
  lab02_name_with_postfix  = lower("${local.lab02_name}${random_string.rid.result}")
  lab03_name_with_postfix  = lower("${local.lab03_name}${random_string.rid.result}")
  lab04_name_with_postfix  = lower("${local.lab04_name}${random_string.rid.result}")
  lab05a_name_with_postfix = lower("${local.lab05a_name}${random_string.rid.result}")
  lab05b_name_with_postfix = lower("${local.lab05b_name}${random_string.rid.result}")
  lab06a_name_with_postfix = lower("${local.lab06a_name}${random_string.rid.result}")
  lab06b_name_with_postfix = lower("${local.lab06b_name}${random_string.rid.result}")
  lab06c_name_with_postfix = lower("${local.lab06c_name}${random_string.rid.result}")
  lab06d_name_with_postfix = lower("${local.lab06d_name}${random_string.rid.result}")
  lab07_name_with_postfix  = lower("${local.lab07_name}${random_string.rid.result}")
  lab08_name_with_postfix  = lower("${local.lab08_name}${random_string.rid.result}")
  lab09a_name_with_postfix = lower("${local.lab09a_name}${random_string.rid.result}")
  lab09b_name_with_postfix = lower("${local.lab09b_name}${random_string.rid.result}")
  lab09c_name_with_postfix = lower("${local.lab09c_name}${random_string.rid.result}")
  lab09d_name_with_postfix = lower("${local.lab09d_name}${random_string.rid.result}")
  lab10_name_with_postfix  = lower("${local.lab10_name}${random_string.rid.result}")
  lab11_name_with_postfix  = lower("${local.lab11_name}${random_string.rid.result}")
  user_name                = "demouser"
  user_passowrd            = "Azuredemo2020"
  vm_size                  = "Standard_B4ms"
  random_str              = random_string.rid.result
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

data "azurerm_client_config" "current" {}

resource "random_string" "rid" {
  length  = 3
  special = false
  numeric  = false
  upper = false
}

resource "random_integer" "rint" {
  min = 100
  max = 999
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "az104" {
  name     = local.group_name
  location = local.location

  tags = {
    environment = local.group_name
  }
}
