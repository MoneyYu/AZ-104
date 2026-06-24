<#
.SYNOPSIS
    Generates realistic demo telemetry across the AZ-104 lab so Monitor /
    Log Analytics / Grafana have real data right after a fresh (night-before) deploy.

.DESCRIPTION
    Because the lab is usually built the evening before class, the monitoring
    tables are empty. This script DRIVES REAL ACTIVITY on the deployed resources
    so genuine logs and metrics are produced (not synthetic rows):

      * HTTP traffic to every public endpoint  -> W3CIISLog, AppServiceHTTPLogs,
        Load Balancer health events + metrics, ACI.
      * VM workload via Run Command            -> Perf, InsightsMetrics, Event
        (incl. Security), Percentage CPU host metric (can trip the CPU alert).
      * Storage blob transactions (Entra auth) -> Storage diagnostics / metrics.
      * Control-plane tag operations           -> AzureActivity.

    Data lands in law-vminsights + Azure Monitor Metrics after the usual
    ~5-15 min ingestion latency. Run it ~20-30 min before class.

.PARAMETER GroupPostfix
    The value passed to Terraform as -var group_postfix (e.g. 0614).

.PARAMETER Rounds
    Number of activity rounds (more = more data / higher load). Default 3.

.EXAMPLE
    ./Generate-DemoData.ps1 -GroupPostfix 0614
.EXAMPLE
    ./Generate-DemoData.ps1 -GroupPostfix 0614 -Rounds 5
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$GroupPostfix,

    [int]$Rounds = 3
)

$ErrorActionPreference = "Continue"
$rg = "AZ104-$GroupPostfix"

function Write-Section($t) { Write-Host "`n========== $t ==========" -ForegroundColor Cyan }

$sub = az account show --query id -o tsv 2>$null
if ([string]::IsNullOrWhiteSpace($sub)) { throw "Not logged in to Azure CLI (run 'az login')." }
Write-Host "Subscription : $sub"
Write-Host "Resource group: $rg"
if ((az group exists -n $rg) -ne "true") { throw "Resource group $rg not found." }

# ---------------------------------------------------------------------------
# Discover endpoints / resources
# ---------------------------------------------------------------------------
Write-Section "Discovering resources"
$pipFqdns = az network public-ip list -g $rg --query "[?dnsSettings.fqdn!=null].dnsSettings.fqdn" -o tsv 2>$null
$pipIps   = az network public-ip list -g $rg --query "[?ipAddress!=null].ipAddress" -o tsv 2>$null
$webHosts = az webapp list -g $rg --query "[].defaultHostName" -o tsv 2>$null
$aciFqdns = az container list -g $rg --query "[?ipAddress.fqdn!=null].ipAddress.fqdn" -o tsv 2>$null
$tmFqdns  = az network traffic-manager profile list -g $rg --query "[].dnsConfig.fqdn" -o tsv 2>$null

$httpTargets = @()
foreach ($x in @($pipFqdns) + @($pipIps) + @($webHosts) + @($aciFqdns) + @($tmFqdns)) {
    if (-not [string]::IsNullOrWhiteSpace($x)) { $httpTargets += "http://$x/" }
}
$httpTargets = $httpTargets | Select-Object -Unique
Write-Host ("HTTP targets : {0}" -f $httpTargets.Count)

$vms = az vm list -g $rg --query "[].name" -o tsv 2>$null
$vms = @($vms | Where-Object { $_ })
Write-Host ("VMs          : {0}" -f $vms.Count)

$stores = az storage account list -g $rg --query "[].name" -o tsv 2>$null
$stores = @($stores | Where-Object { $_ })
Write-Host ("Storage accts: {0}" -f $stores.Count)

# ---------------------------------------------------------------------------
# 1. HTTP traffic  -> IIS / App Service / Load Balancer / ACI
# ---------------------------------------------------------------------------
Write-Section "1/4 HTTP traffic"
if ($httpTargets.Count -gt 0) {
    $reqs = 60 * $Rounds
    Write-Host "Sending ~$reqs requests per endpoint..."
    $jobs = foreach ($t in $httpTargets) {
        Start-Job -ArgumentList $t, $reqs -ScriptBlock {
            param($url, $n)
            $ok = 0
            for ($i = 0; $i -lt $n; $i++) {
                try { Invoke-WebRequest -Uri $url -TimeoutSec 5 -UseBasicParsing | Out-Null; $ok++ } catch {}
                try { Invoke-WebRequest -Uri ($url + "notfound-$i") -TimeoutSec 5 -UseBasicParsing | Out-Null } catch {}
            }
            "$url -> $ok ok"
        }
    }
    $jobs | Wait-Job -Timeout (120 * $Rounds) | Out-Null
    $jobs | ForEach-Object { Receive-Job $_ 2>$null | ForEach-Object { Write-Host "  $_" } ; Remove-Job $_ -Force }
} else {
    Write-Host "No public HTTP endpoints found; skipping."
}

# ---------------------------------------------------------------------------
# 2. VM workload via Run Command -> Perf / InsightsMetrics / Event / CPU metric
# ---------------------------------------------------------------------------
Write-Section "2/4 VM workload (events, disk I/O, CPU)"
$cpuSeconds = 45 * $Rounds
$vmScript = @"
# Windows event log entries (Application + System + a couple of failures)
1..20 | ForEach-Object { eventcreate /T INFORMATION /ID 700 /L APPLICATION /SO AZ104Demo /D ('AZ-104 demo info ' + `$_) 2>`$null | Out-Null }
1..6  | ForEach-Object { eventcreate /T WARNING     /ID 701 /L SYSTEM      /SO AZ104Demo /D ('AZ-104 demo warn ' + `$_) 2>`$null | Out-Null }
1..3  | ForEach-Object { eventcreate /T ERROR       /ID 702 /L APPLICATION /SO AZ104Demo /D ('AZ-104 demo error ' + `$_) 2>`$null | Out-Null }
# Disk I/O -> LogicalDisk perf counters
`$f = 'C:\az104demo.bin'
1..4 | ForEach-Object { fsutil file createnew `$f 104857600 | Out-Null; [System.IO.File]::ReadAllBytes(`$f) | Out-Null; Remove-Item `$f -Force -EA SilentlyContinue }
# CPU load (multi-core) for ~$cpuSeconds s -> Percentage CPU host metric + Perf
`$end = (Get-Date).AddSeconds($cpuSeconds)
1..([Environment]::ProcessorCount) | ForEach-Object {
    Start-Job { param(`$e) while ((Get-Date) -lt `$e) { [Math]::Sqrt(([double](Get-Random)) ) | Out-Null } } -ArgumentList `$end | Out-Null
}
Get-Job | Wait-Job | Out-Null; Get-Job | Remove-Job -Force
'vm workload done'
"@
$vmJobs = foreach ($vm in $vms) {
    Start-Job -ArgumentList $rg, $vm, $vmScript -ScriptBlock {
        param($rg, $vm, $script)
        $tmp = New-TemporaryFile
        Set-Content -Path $tmp.FullName -Value $script -Encoding ascii
        $r = az vm run-command invoke -g $rg -n $vm --command-id RunPowerShellScript --scripts "@$($tmp.FullName)" -o json 2>$null
        Remove-Item $tmp.FullName -Force -EA SilentlyContinue
        if ($r) { "$vm -> ran" } else { "$vm -> skipped (stopped/no agent)" }
    }
}
if ($vmJobs) {
    $vmJobs | Wait-Job -Timeout (90 + $cpuSeconds * 2) | Out-Null
    $vmJobs | ForEach-Object { Receive-Job $_ 2>$null | ForEach-Object { Write-Host "  $_" }; Remove-Job $_ -Force }
} else { Write-Host "No VMs found; skipping." }

# ---------------------------------------------------------------------------
# 3. Storage blob transactions (Entra ID auth -- no account keys)
# ---------------------------------------------------------------------------
Write-Section "3/4 Storage transactions"
foreach ($sa in $stores) {
    try {
        $container = "az104demo"
        az storage container create --account-name $sa --name $container --auth-mode login --only-show-errors 2>$null | Out-Null
        $tmp = New-TemporaryFile
        "AZ-104 demo blob $(Get-Date)" | Set-Content $tmp.FullName
        1..(3 * $Rounds) | ForEach-Object {
            az storage blob upload --account-name $sa --container-name $container --name "demo-$_.txt" --file $tmp.FullName --auth-mode login --overwrite --only-show-errors 2>$null | Out-Null
        }
        az storage blob list --account-name $sa --container-name $container --auth-mode login --only-show-errors -o none 2>$null
        Remove-Item $tmp.FullName -Force -EA SilentlyContinue
        Write-Host "  $sa -> blob read/write/list done"
    } catch { Write-Host "  $sa -> skipped ($($_.Exception.Message))" }
}
if ($stores.Count -eq 0) { Write-Host "No storage accounts found; skipping." }

# ---------------------------------------------------------------------------
# 4. Control-plane operations -> AzureActivity
# ---------------------------------------------------------------------------
Write-Section "4/4 Control-plane activity (tags -> AzureActivity)"
$ids = az resource list -g $rg --query "[].id" -o tsv 2>$null | Select-Object -First 12
for ($r = 0; $r -lt $Rounds; $r++) {
    foreach ($id in $ids) {
        az tag update --resource-id $id --operation Merge --tags "az104demo=round$r" --only-show-errors -o none 2>$null
    }
    az tag update --resource-id "/subscriptions/$sub/resourceGroups/$rg" --operation Merge --tags "az104demo=round$r" --only-show-errors -o none 2>$null
}
foreach ($id in $ids) { az tag update --resource-id $id --operation Delete --tags "az104demo" --only-show-errors -o none 2>$null }
Write-Host "  tagged/untagged $($ids.Count) resources x $Rounds rounds"

Write-Section "Done"
Write-Host "Demo activity generated. Allow ~5-15 min for ingestion, then check:"
Write-Host "  - Log Analytics (law-vminsights): AzureActivity, Perf, Event, W3CIISLog, AzureDiagnostics, AzureMetrics"
Write-Host "  - Azure Monitor Metrics: Percentage CPU on the VMs"
Write-Host "  - Grafana: AZ-104 | Monitor Overview / VM Guest Insights dashboards"
