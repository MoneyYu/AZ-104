<#
.SYNOPSIS
    Imports the AZ-104 demo dashboards into the lab's Azure Managed Grafana instance.

.DESCRIPTION
    Azure Managed Grafana dashboards are NOT managed by Terraform here (to avoid coupling
    every `terraform plan/apply` to a live Grafana API token). Run this script once AFTER
    `terraform apply` to pre-load demo dashboards so Grafana shows real data during the
    Monitor (M11) chapter instead of looking empty.

    The script discovers the Grafana instance and the central Log Analytics workspace from
    the resource group, substitutes the workspace resource ID into each dashboard JSON
    (the __WORKSPACE_ID__ placeholder), and imports them via the Azure CLI `amg` extension.

.PARAMETER GroupPostfix
    The same value passed to Terraform as -var group_postfix (default: 0614).

.EXAMPLE
    ./Import-GrafanaDashboards.ps1 -GroupPostfix 0614
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$GroupPostfix
)

$ErrorActionPreference = "Stop"
$rg = "AZ104-$GroupPostfix"

# Ensure the Azure Managed Grafana CLI extension is available.
az config set extension.dynamic_install_allow_preview=true --only-show-errors | Out-Null
az extension add -n amg --only-show-errors 2>$null

Write-Host "Resource group: $rg"

$grafana = az grafana list -g $rg --query "[?contains(name,'grafana')].name | [0]" -o tsv
if ([string]::IsNullOrWhiteSpace($grafana)) { throw "No Managed Grafana found in $rg" }
Write-Host "Grafana instance: $grafana"

$workspaceId = az monitor log-analytics workspace list -g $rg --query "[?contains(name,'law-vminsights')].id | [0]" -o tsv
if ([string]::IsNullOrWhiteSpace($workspaceId)) { throw "No law-vminsights workspace found in $rg" }
Write-Host "Workspace ID: $workspaceId"

$dashboardDir = Join-Path $PSScriptRoot "."
$jsonFiles = Get-ChildItem -Path $dashboardDir -Filter "*.json"

foreach ($file in $jsonFiles) {
    Write-Host "`nImporting $($file.Name) ..."
    $definition = (Get-Content $file.FullName -Raw).Replace("__WORKSPACE_ID__", $workspaceId)
    $tmp = New-TemporaryFile
    Set-Content -Path $tmp.FullName -Value $definition -Encoding utf8
    try {
        az grafana dashboard create --name $grafana -g $rg --definition $tmp.FullName --overwrite --only-show-errors | Out-Null
        Write-Host "  -> imported OK" -ForegroundColor Green
    }
    finally {
        Remove-Item $tmp.FullName -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`nDone. Open Grafana: $(az grafana show --name $grafana -g $rg --query 'properties.endpoint' -o tsv)"
