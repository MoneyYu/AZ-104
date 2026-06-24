## LAB-10-BACKUP
resource "azurerm_recovery_services_vault" "lab10" {
  name                = "${local.lab10_name}-recovery-vault-${local.random_str}"
  location            = azurerm_resource_group.az104.location
  resource_group_name = azurerm_resource_group.az104.name
  sku                 = "Standard"

  tags = local.default_tags
}

resource "azurerm_monitor_diagnostic_setting" "lab10_recovery_services_vault" {
  name                       = "${azurerm_recovery_services_vault.lab10.name}-diag"
  target_resource_id         = azurerm_recovery_services_vault.lab10.id
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
}