<#
.SYNOPSIS
    Demonstrates M06F Network Watcher packet capture between the two lab06b VMs.

.DESCRIPTION
    Starts a Network Watcher packet capture on the target VM, filtered to TCP port 80
    traffic with the peer VM, generates HTTP traffic from inside the target VM, stops
    the capture, and reports where the .cap file landed.

    The M06F flow-log storage account has Shared Key authentication disabled. Network
    Watcher packet capture uploads to Storage with Shared Key only, so this demo saves
    the capture to a local path on the VM instead of to a storage account.

.EXAMPLE
    .\DEMO\Module06\NW-PacketCapture.ps1 -ResourceGroup AZ104-0915
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [ValidateNotNullOrEmpty()]
    [string]$VmName = "lab06b-vm01-cat",

    [ValidateNotNullOrEmpty()]
    [string]$PeerVmName = "lab06b-vm02-cat",

    [ValidateNotNullOrEmpty()]
    [string]$NetworkWatcherName = "NetworkWatcher_japaneast",

    [ValidateNotNullOrEmpty()]
    [string]$NetworkWatcherResourceGroup = "NetworkWatcherRG",

    [ValidateNotNullOrEmpty()]
    [string]$CaptureName = "lab06b-http-capture",

    [ValidateNotNullOrEmpty()]
    [string]$CaptureFilePath = "C:\CaptureLogs\lab06b-http-capture.cap",

    [ValidateRange(30, 300)]
    [int]$CaptureDurationSeconds = 120,

    [ValidateRange(1, 100)]
    [int]$CaptureLimitMiB = 10,

    [ValidateRange(1, 60)]
    [int]$RequestCount = 10
)

$ErrorActionPreference = "Stop"

# This script checks $LASTEXITCODE itself so it can name the failed resource. If the
# caller inherited $PSNativeCommandUseErrorActionPreference = $true, a failing az call
# would instead throw a bare NativeCommandExitException, and the stop call in the
# finally block below would replace the failure that actually broke the demo.
$PSNativeCommandUseErrorActionPreference = $false

function Invoke-AzCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$FailureMessage
    )

    $output = & az @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$FailureMessage Azure CLI exited with code $LASTEXITCODE."
    }

    return ($output -join [Environment]::NewLine).Trim()
}

function Invoke-VmPowerShell {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $true)]
        [string]$TargetVmName,

        [Parameter(Mandatory = $true)]
        [string]$ScriptText,

        [Parameter(Mandatory = $true)]
        [string]$FailureMessage
    )

    $scriptLines = @($ScriptText -split "`r?`n" | Where-Object { $_.Trim().Length -gt 0 })

    # --scripts consumes every following value, so it has to stay last.
    $arguments = @(
        "vm", "run-command", "invoke",
        "--resource-group", $ResourceGroupName,
        "--name", $TargetVmName,
        "--command-id", "RunPowerShellScript",
        "--output", "json",
        "--only-show-errors",
        "--scripts"
    ) + $scriptLines

    $json = Invoke-AzCommand -Arguments $arguments -FailureMessage $FailureMessage
    if ([string]::IsNullOrWhiteSpace($json)) {
        throw "$FailureMessage Azure CLI returned no run-command output."
    }

    $result = $json | ConvertFrom-Json
    return (@($result.value | ForEach-Object { $_.message }) -join [Environment]::NewLine)
}

Write-Host "`nM06F Network Watcher packet capture" -ForegroundColor Cyan

# packet-capture list/show/show-status/stop are region scoped, so the Network Watcher
# name and resource group are only used to resolve that region.
$watcherRows = Invoke-AzCommand -Arguments @(
    "network", "watcher", "list",
    "--query", "[].[name,resourceGroup,location]",
    "--output", "tsv",
    "--only-show-errors"
) -FailureMessage "Unable to list Network Watchers in the current subscription."

$watcherLocation = $null
foreach ($row in ($watcherRows -split "`r?`n")) {
    $columns = $row -split "`t"
    if ($columns.Count -lt 3) {
        continue
    }
    if ($columns[0].Trim() -eq $NetworkWatcherName -and $columns[1].Trim() -eq $NetworkWatcherResourceGroup) {
        $watcherLocation = $columns[2].Trim()
        break
    }
}
if ([string]::IsNullOrWhiteSpace($watcherLocation)) {
    throw "Network Watcher '$NetworkWatcherName' was not found in resource group '$NetworkWatcherResourceGroup'. Run 'az network watcher list --output table' to see the Network Watchers in this subscription."
}
Write-Host "Network Watcher : $NetworkWatcherName ($NetworkWatcherResourceGroup, region $watcherLocation)"

$peerPrivateIp = Invoke-AzCommand -Arguments @(
    "vm", "list-ip-addresses",
    "--resource-group", $ResourceGroup,
    "--name", $PeerVmName,
    "--query", "[0].virtualMachine.network.privateIpAddresses[0]",
    "--output", "tsv",
    "--only-show-errors"
) -FailureMessage "Unable to read the IP addresses of peer VM '$PeerVmName' in resource group '$ResourceGroup'."

if ([string]::IsNullOrWhiteSpace($peerPrivateIp)) {
    throw "Peer VM '$PeerVmName' in resource group '$ResourceGroup' has no private IP address. Confirm that the M06F environment is deployed."
}

$parsedPeerIp = [System.Net.IPAddress]::None
if (-not [System.Net.IPAddress]::TryParse($peerPrivateIp, [ref]$parsedPeerIp)) {
    throw "Azure CLI returned '$peerPrivateIp' as the private IP address of peer VM '$PeerVmName', which is not a valid IP address."
}
Write-Host "Peer VM         : $PeerVmName ($peerPrivateIp)"

# A stopped session keeps its name, and Azure rejects a second capture with the same
# name, so fail on any existing session instead of overwriting the trainer's evidence.
$existingCaptureNames = Invoke-AzCommand -Arguments @(
    "network", "watcher", "packet-capture", "list",
    "--location", $watcherLocation,
    "--query", "[].name",
    "--output", "tsv",
    "--only-show-errors"
) -FailureMessage "Unable to list packet capture sessions in region '$watcherLocation'."

$conflictingCaptures = @($existingCaptureNames -split "`r?`n" | Where-Object { $_.Trim() -eq $CaptureName })
if ($conflictingCaptures.Count -gt 0) {
    $existingStatusOutput = & az network watcher packet-capture show-status `
        --location $watcherLocation `
        --name $CaptureName `
        --query "packetCaptureStatus" `
        --output tsv `
        --only-show-errors
    if ($LASTEXITCODE -eq 0) {
        $existingStatus = ($existingStatusOutput -join [Environment]::NewLine).Trim()
    }
    else {
        $existingStatus = "unavailable, show-status exited with code $LASTEXITCODE"
    }
    throw "Packet capture session '$CaptureName' already exists in region '$watcherLocation' (status: $existingStatus). This demo does not overwrite it. Delete the old session first with: az network watcher packet-capture delete --location $watcherLocation --name $CaptureName"
}

$ensureDirectoryTemplate = @'
$captureFilePath = '__CAPTURE_FILE_PATH__'
$captureDirectory = Split-Path -Path $captureFilePath -Parent
if (-not (Test-Path -LiteralPath $captureDirectory)) {
    [void](New-Item -ItemType Directory -Path $captureDirectory -Force)
}
if (Test-Path -LiteralPath $captureDirectory) {
    Write-Output ('CAPTURE_DIR_READY=' + $captureDirectory)
}
$previousTicks = 0
if (Test-Path -LiteralPath $captureFilePath) {
    $previousTicks = (Get-Item -LiteralPath $captureFilePath).LastWriteTimeUtc.Ticks
}
Write-Output ('CAPTURE_FILE_PREVIOUS_TICKS=' + $previousTicks)
'@

$ensureDirectoryScript = $ensureDirectoryTemplate.Replace('__CAPTURE_FILE_PATH__', $CaptureFilePath)

Write-Host "`nPreparing the capture directory on '$VmName'" -ForegroundColor Cyan
$ensureDirectoryMessages = Invoke-VmPowerShell `
    -ResourceGroupName $ResourceGroup `
    -TargetVmName $VmName `
    -ScriptText $ensureDirectoryScript `
    -FailureMessage "Unable to prepare the capture directory for '$CaptureFilePath' on VM '$VmName'."

if ($ensureDirectoryMessages -notlike "*CAPTURE_DIR_READY=*") {
    Write-Host $ensureDirectoryMessages
    throw "VM '$VmName' did not report the capture directory for '$CaptureFilePath' as ready. Confirm that the VM is running and that the Run Command extension is healthy."
}

$previousCaptureTicks = 0
if ($ensureDirectoryMessages -match 'CAPTURE_FILE_PREVIOUS_TICKS=(\d+)') {
    $previousCaptureTicks = [long]$Matches[1]
}
Write-Host "Capture directory ready for $CaptureFilePath"

$captureLimitBytes = [long]$CaptureLimitMiB * 1MB
$captureFilter = "[{protocol:TCP,remote-ip-address:$peerPrivateIp,remote-port:80}]"

# Each request costs at most the 5 second timeout plus the 1 second pause below.
$worstCaseTrafficSeconds = $RequestCount * 6
if ($worstCaseTrafficSeconds -gt $CaptureDurationSeconds) {
    Write-Warning "Traffic generation can take up to $worstCaseTrafficSeconds seconds when requests time out, which is longer than the $CaptureDurationSeconds second capture time limit. The capture would stop by itself before the traffic finishes. Raise -CaptureDurationSeconds or lower -RequestCount."
}

Write-Host "`nStarting packet capture '$CaptureName' on '$VmName'" -ForegroundColor Cyan
Write-Host "Filter        : TCP port 80 with $peerPrivateIp"
Write-Host "Saved on VM   : $CaptureFilePath"
Write-Host "Time limit    : $CaptureDurationSeconds seconds"
Write-Host "Capture limit : $captureLimitBytes bytes ($CaptureLimitMiB MiB)"

$createOutput = Invoke-AzCommand -Arguments @(
    "network", "watcher", "packet-capture", "create",
    "--resource-group", $ResourceGroup,
    "--name", $CaptureName,
    "--vm", $VmName,
    "--target-type", "AzureVM",
    "--file-path", $CaptureFilePath,
    "--time-limit", "$CaptureDurationSeconds",
    "--capture-limit", "$captureLimitBytes",
    "--filters", $captureFilter,
    "--output", "jsonc",
    "--only-show-errors"
) -FailureMessage "Unable to create packet capture '$CaptureName' on VM '$VmName' in resource group '$ResourceGroup'."
Write-Host $createOutput

$trafficTemplate = @'
$targetUrl = 'http://__PEER_IP__/'
$requestCount = __REQUEST_COUNT__
$successCount = 0
for ($requestNumber = 1; $requestNumber -le $requestCount; $requestNumber++) {
    try {
        $response = Invoke-WebRequest -Uri $targetUrl -UseBasicParsing -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            $successCount++
        }
        else {
            Write-Output ('TRAFFIC_REQUEST_STATUS=' + $requestNumber + ':' + $response.StatusCode)
        }
    }
    catch {
        Write-Output ('TRAFFIC_REQUEST_ERROR=' + $requestNumber + ':' + $_.Exception.Message)
    }
    Start-Sleep -Seconds 1
}
Write-Output ('TRAFFIC_SUCCESS=' + $successCount + '/' + $requestCount)
'@

$trafficScript = $trafficTemplate.Replace('__PEER_IP__', $peerPrivateIp).Replace('__REQUEST_COUNT__', "$RequestCount")

# Everything between the running capture and the stop call belongs in try/finally so a
# failed check never leaves a billable capture session running on the VM.
$stopFailureMessage = $null
try {
    $captureStatus = $null
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $captureStatus = Invoke-AzCommand -Arguments @(
            "network", "watcher", "packet-capture", "show-status",
            "--location", $watcherLocation,
            "--name", $CaptureName,
            "--query", "packetCaptureStatus",
            "--output", "tsv",
            "--only-show-errors"
        ) -FailureMessage "Unable to read the status of packet capture '$CaptureName' in region '$watcherLocation'."

        if ($captureStatus -eq "Running") {
            break
        }
        Start-Sleep -Seconds 5
    }
    if ($captureStatus -ne "Running") {
        throw "Packet capture '$CaptureName' reports status '$captureStatus' instead of 'Running', so the demo traffic would not be captured."
    }
    Write-Host "Capture status: $captureStatus"

    Write-Host "`nGenerating $RequestCount HTTP requests from '$VmName' to http://$peerPrivateIp/" -ForegroundColor Cyan
    $trafficMessages = Invoke-VmPowerShell `
        -ResourceGroupName $ResourceGroup `
        -TargetVmName $VmName `
        -ScriptText $trafficScript `
        -FailureMessage "Unable to generate HTTP traffic from VM '$VmName' to 'http://$peerPrivateIp/'."
    Write-Host $trafficMessages

    if ($trafficMessages -match 'TRAFFIC_SUCCESS=(\d+)/(\d+)') {
        $successfulRequests = [int]$Matches[1]
    }
    else {
        throw "VM '$VmName' did not report an HTTP request summary, so the generated traffic cannot be confirmed."
    }
    if ($successfulRequests -lt 1) {
        throw "None of the $RequestCount HTTP requests from '$VmName' to 'http://$peerPrivateIp/' succeeded, so no HTTP traffic matched the capture filter. Check that IIS is running on '$PeerVmName' and that the NSG allows TCP 80."
    }
    Write-Host "Successful HTTP requests: $successfulRequests of $RequestCount"
}
finally {
    Write-Host "`nStopping packet capture '$CaptureName'" -ForegroundColor Cyan
    & az network watcher packet-capture stop `
        --location $watcherLocation `
        --name $CaptureName `
        --only-show-errors
    if ($LASTEXITCODE -ne 0) {
        # Never throw or stop from finally: that would replace an earlier failure.
        $stopFailureMessage = "Unable to stop packet capture '$CaptureName' in region '$watcherLocation'. Azure CLI exited with code $LASTEXITCODE. Stop it manually with: az network watcher packet-capture stop --location $watcherLocation --name $CaptureName"
        Write-Warning $stopFailureMessage -WarningAction Continue
    }
    else {
        Write-Host "Packet capture '$CaptureName' stopped."
    }
}

if ($null -ne $stopFailureMessage) {
    throw $stopFailureMessage
}

Write-Host "`nPacket capture status" -ForegroundColor Cyan
$statusOutput = Invoke-AzCommand -Arguments @(
    "network", "watcher", "packet-capture", "show-status",
    "--location", $watcherLocation,
    "--name", $CaptureName,
    "--output", "jsonc",
    "--only-show-errors"
) -FailureMessage "Unable to read the status of packet capture '$CaptureName' in region '$watcherLocation'."
Write-Host $statusOutput

Write-Host "`nPacket capture details" -ForegroundColor Cyan
$detailsOutput = Invoke-AzCommand -Arguments @(
    "network", "watcher", "packet-capture", "show",
    "--location", $watcherLocation,
    "--name", $CaptureName,
    "--output", "jsonc",
    "--only-show-errors"
) -FailureMessage "Unable to read the details of packet capture '$CaptureName' in region '$watcherLocation'."
Write-Host $detailsOutput

$verifyTemplate = @'
$captureFilePath = '__CAPTURE_FILE_PATH__'
if (Test-Path -LiteralPath $captureFilePath) {
    $captureFile = Get-Item -LiteralPath $captureFilePath
    Write-Output ('CAPTURE_FILE_BYTES=' + $captureFile.Length)
    Write-Output ('CAPTURE_FILE_TICKS=' + $captureFile.LastWriteTimeUtc.Ticks)
    Write-Output ('CAPTURE_FILE_WRITTEN_UTC=' + $captureFile.LastWriteTimeUtc.ToString('s'))
}
else {
    Write-Output 'CAPTURE_FILE_MISSING'
    $captureDirectory = Split-Path -Path $captureFilePath -Parent
    if (Test-Path -LiteralPath $captureDirectory) {
        foreach ($item in Get-ChildItem -LiteralPath $captureDirectory -File) {
            Write-Output ('CAPTURE_DIR_ITEM=' + $item.Name + ':' + $item.Length)
        }
    }
}
'@

$verifyScript = $verifyTemplate.Replace('__CAPTURE_FILE_PATH__', $CaptureFilePath)

$verifyMessages = Invoke-VmPowerShell `
    -ResourceGroupName $ResourceGroup `
    -TargetVmName $VmName `
    -ScriptText $verifyScript `
    -FailureMessage "Unable to inspect '$CaptureFilePath' on VM '$VmName'."

if ($verifyMessages -notmatch 'CAPTURE_FILE_BYTES=(\d+)') {
    Write-Host $verifyMessages
    throw "Packet capture file '$CaptureFilePath' was not found on VM '$VmName'. Review the capture details above for a packetCaptureError value."
}
$captureBytes = [long]$Matches[1]

if ($captureBytes -le 0) {
    throw "Packet capture file '$CaptureFilePath' on VM '$VmName' is 0 bytes, so nothing matched the TCP port 80 filter for $peerPrivateIp."
}

if ($verifyMessages -notmatch 'CAPTURE_FILE_TICKS=(\d+)') {
    throw "VM '$VmName' did not report a last write time for '$CaptureFilePath', so this capture cannot be distinguished from an older file."
}
$captureTicks = [long]$Matches[1]
if ($captureTicks -le $previousCaptureTicks) {
    throw "Packet capture file '$CaptureFilePath' on VM '$VmName' was not updated by this session; it is left over from an earlier capture. Review the capture details above for a packetCaptureError value."
}

$captureWrittenUtc = "unknown"
if ($verifyMessages -match 'CAPTURE_FILE_WRITTEN_UTC=(\S+)') {
    $captureWrittenUtc = $Matches[1]
}

Write-Host "`nCapture file on the VM" -ForegroundColor Cyan
Write-Host "VM           : $VmName"
Write-Host "Path         : $CaptureFilePath"
Write-Host "Size         : $captureBytes bytes ($([math]::Round($captureBytes / 1KB, 1)) KiB)"
Write-Host "Last written : $captureWrittenUtc UTC"

Write-Host "`nWhy the capture is not in a storage account" -ForegroundColor Cyan
Write-Host "Network Watcher uploads packet captures to Storage with Shared Key only, and the M06F flow-log storage account has Shared Key disabled. Saving to a local VM path is therefore the supported option here, and this script does not download the file."

Write-Host "`nHow to collect the .cap file" -ForegroundColor Cyan
Write-Host "- Connect to $VmName over an approved admin path such as Azure Bastion, then copy $CaptureFilePath to your workstation and open it in Wireshark."
Write-Host "- If the file has to leave the VM without an interactive session, arrange a separately approved Microsoft Entra authenticated transfer, for example AzCopy with an Entra login against a storage account where the operator holds a data plane RBAC role. Do not re-enable Shared Key on the flow-log storage account."

Write-Host "`nBefore running this demo again" -ForegroundColor Cyan
Write-Host "Delete the finished session: az network watcher packet-capture delete --location $watcherLocation --name $CaptureName"
