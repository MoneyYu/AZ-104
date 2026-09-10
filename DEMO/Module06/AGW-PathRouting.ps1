<#
.SYNOPSIS
    Demonstrates M06C Application Gateway path-based routing.

.EXAMPLE
    .\DEMO\Module06\AGW-PathRouting.ps1 -ResourceGroup AZ104-0614
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [ValidateNotNullOrEmpty()]
    [string]$GatewayName = "lab06c-appgw-cat",

    [ValidateNotNullOrEmpty()]
    [string]$PublicIpName = "lab06c-pip-cat",

    [ValidateRange(1, 100)]
    [int]$RequestCount = 6
)

$ErrorActionPreference = "Stop"

$fqdnOutput = & az network public-ip show `
    --resource-group $ResourceGroup `
    --name $PublicIpName `
    --query "dnsSettings.fqdn" `
    --output tsv `
    --only-show-errors
if ($LASTEXITCODE -ne 0) {
    throw "Unable to read Public IP '$PublicIpName' in resource group '$ResourceGroup'. Azure CLI exited with code $LASTEXITCODE."
}

$fqdn = ($fqdnOutput -join [Environment]::NewLine).Trim()
if ([string]::IsNullOrWhiteSpace($fqdn)) {
    throw "Public IP '$PublicIpName' does not have dnsSettings.fqdn. Confirm that the M06C environment is deployed."
}

$rootUrl = "http://$fqdn/"
$imagesUrl = "http://$fqdn/images/"
$videoUrl = "http://$fqdn/video/"
$legacyUrl = "http://$fqdn/legacy/"

Write-Host "`nM06C Application Gateway URLs" -ForegroundColor Cyan
Write-Host "Root   : $rootUrl"
Write-Host "Images : $imagesUrl"
Write-Host "Video  : $videoUrl"
Write-Host "Legacy : $legacyUrl"

Write-Host "`nApplication Gateway backend health" -ForegroundColor Cyan
& az network application-gateway show-backend-health `
    --resource-group $ResourceGroup `
    --name $GatewayName `
    --query "backendAddressPools[].{pool:(backendAddressPool.name || backendAddressPool.id),servers:backendHttpSettingsCollection[].servers[].{address:address,health:health}}" `
    --output jsonc `
    --only-show-errors
if ($LASTEXITCODE -ne 0) {
    throw "Unable to read backend health for Application Gateway '$GatewayName'. Azure CLI exited with code $LASTEXITCODE."
}

Write-Host "`nRoot route: default pool load balancing (vm01 + vm02)" -ForegroundColor Cyan
for ($request = 1; $request -le $RequestCount; $request++) {
    Write-Host "Request $request of ${RequestCount}: " -NoNewline
    & curl.exe `
        --silent `
        --show-error `
        --max-time 15 `
        --write-out "`nHTTP status: %{http_code}`n" `
        $rootUrl
    if ($LASTEXITCODE -ne 0) {
        throw "curl.exe failed for root request $request ('$rootUrl') with exit code $LASTEXITCODE."
    }
    Write-Host
}

Write-Host "`nImages route: vm03 receives /images/" -ForegroundColor Cyan
& curl.exe `
    --silent `
    --show-error `
    --max-time 15 `
    --write-out "`nHTTP status: %{http_code}`n" `
    $imagesUrl
if ($LASTEXITCODE -ne 0) {
    throw "curl.exe failed for '$imagesUrl' with exit code $LASTEXITCODE."
}
Write-Host

Write-Host "`nVideo route: vm04 receives / because of the backend path override" -ForegroundColor Cyan
& curl.exe `
    --silent `
    --show-error `
    --max-time 15 `
    --write-out "`nHTTP status: %{http_code}`n" `
    $videoUrl
if ($LASTEXITCODE -ne 0) {
    throw "curl.exe failed for '$videoUrl' with exit code $LASTEXITCODE."
}
Write-Host

Write-Host "`nLegacy route: do not follow the redirect (expected HTTP status: 301)" -ForegroundColor Cyan
$legacyResponse = @(& curl.exe `
    --silent `
    --show-error `
    --max-time 15 `
    --output NUL `
    --write-out "%{http_code}`n%{redirect_url}" `
    $legacyUrl)
if ($LASTEXITCODE -ne 0) {
    throw "curl.exe failed for '$legacyUrl' with exit code $LASTEXITCODE."
}
if ($legacyResponse.Count -lt 1) {
    throw "curl.exe returned no HTTP status for '$legacyUrl'."
}
$legacyStatus = $legacyResponse[0].Trim()
$legacyTarget = ($legacyResponse | Select-Object -Skip 1) -join [Environment]::NewLine
Write-Host "HTTP status: $legacyStatus"
Write-Host "Redirect target: $($legacyTarget.Trim())"
if ($legacyStatus -ne "301") {
    throw "Expected '$legacyUrl' to return HTTP 301, but received HTTP $legacyStatus."
}

Write-Host "`nCopy this KQL query into Log Analytics after IIS logs have been ingested:" -ForegroundColor Cyan
@'
W3CIISLog
| where TimeGenerated > ago(30m)
| where Computer in~ ("lab06c-vm03-cat", "lab06c-vm04-cat")
| project TimeGenerated, Computer, csUriStem, scStatus
| order by TimeGenerated desc
'@ | Write-Host
