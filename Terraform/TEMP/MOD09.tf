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

resource "azurerm_application_insights" "lab09a" {
  name                = local.lab09a_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  application_type    = "web"

  tags = {
    environment = local.group_name
  }
}

## LAB-9-B-ACI
# Create Container Instance
resource "azurerm_container_group" "lab09b" {
  name                = local.lab09b_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  ip_address_type     = "public"
  dns_name_label      = local.lab09b_name_with_postfix
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

## LAB-9-C-AKS
resource "azurerm_kubernetes_cluster" "lab09c" {
  name                = local.lab09c_name_with_postfix
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  dns_prefix          = local.lab09c_name

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  addon_profile {
    aci_connector_linux {
      enabled = false
    }

    azure_policy {
      enabled = false
    }

    http_application_routing {
      enabled = false
    }

    kube_dashboard {
      enabled = true
    }

    oms_agent {
      enabled = false
    }
  }
}

