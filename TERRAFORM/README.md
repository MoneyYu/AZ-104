# AZ-104 Terraform backup environment

此目錄提供講師上課用的備援環境。根目錄的 `MAIN.tf` 與 `MOD*.tf` 是目前會載入的設定；`TEMP\` 只存放停用模組，不會被 Terraform 自動載入。

## Prerequisites

- Terraform 與 Azure CLI 已安裝。
- 已使用 `az login` 登入，並確認目前訂閱。
- 已確認目前工作目錄為本 repo 根目錄；以下指令統一使用 `-chdir=TERRAFORM`。
- 已選定唯一的 `group_postfix`；它會決定 Resource Group 名稱 `AZ104-<postfix>`。
- 同一個 workspace 與 state 同時間只能有一位操作者。

```powershell
az account show --query '{subscription:id,state:state}' --output json
terraform -chdir=TERRAFORM workspace show
terraform -chdir=TERRAFORM state list
```

部署前必須由執行者親自檢查完整 plan；不得套用診斷用 targeted plan 或過期的 plan binary。`terraform destroy` 需要另外確認影響範圍。

## Validate

只格式化本次修改的檔案，避免變更其他教材：

```powershell
terraform -chdir=TERRAFORM fmt MOD05B.tf
terraform -chdir=TERRAFORM fmt -check -diff MOD05B.tf MOD05D.tf
terraform -chdir=TERRAFORM validate -no-color
```

不要在 East Asia Hub 仍為 tainted 時建立或部署完整 plan；Terraform 會規劃替換該 Hub。先完成下方 M05D Router 復原及 guarded untaint，再產生新的完整 plan。

## Resource conventions

### Public IP DNS names

根目錄 active 模組的每個 `azurerm_public_ip` 都必須設定 `domain_name_label`，並沿用與 Public IP 資源名稱相同的值。例如：

```hcl
name              = "${local.lab05a_name}-pip-01-${local.random_str}"
domain_name_label = "${local.lab05a_name}-pip-01-${local.random_str}"
```

Azure 會依區域產生 `<label>.<region>.cloudapp.azure.com` FQDN。DNS label 在同一 Azure 區域必須唯一；目前 label 不含 `group_postfix`，因此同一區域同時部署多套環境時可能發生命名衝突。

### Lab05A shared network security groups

[Network security groups](https://learn.microsoft.com/azure/virtual-network/network-security-group-how-it-works) 可以關聯多個 subnet 或 network interface。NSG 是區域性資源，因此本環境依區域共用：

- `lab05a-nsg-jpe-cat` 位於 Japan East，由 vnet-01 與 vnet-02 的 `default` subnet 共用。
- `lab05a-nsg-03-cat` 位於 East Asia，只關聯 vnet-03 的 `default` subnet。

不要把 East Asia subnet 改為使用 Japan East 的共用 NSG。修改 NSG 佈局後，完整 plan 必須確認三個 subnet 都仍有 NSG association。

## M05B: AZ VPN Gateway public IP

本環境建立 `VpnGw3AZ` 時，Azure 回傳：

```text
VmssVpnGatewayPublicIpsMustHaveZonesConfigured:
Standard Public IPs associated with VPN Gateways with AZ VPN skus must have zones configured.
```

因此 Public IP 明確指定三個 Availability Zones；zones 也會決定 AZ Gateway instance 的部署位置。本 repo 使用：

```hcl
zones = ["1", "2", "3"]
```

在 AzureRM 4.78.0 中，變更 `azurerm_public_ip.zones` 會替換 Public IP。即使原 Public IP 尚未關聯 Gateway，仍可能取得新的 IP 位址；部署前必須確認沒有新關聯，並接受位址變更。

Public IP 的 `lifecycle` 必須保留：

```hcl
lifecycle {
  ignore_changes = [ip_tags]
}
```

訂閱政策會注入 `FirstPartyUsage` IP tag；移除 ignore 可能引起與本次修正無關的 replacement。

### Preview the M05B change

Targeted plan 只能用於診斷，不可直接部署，也不包含所有下游 consumer：

```powershell
$env:ARM_RESOURCE_PROVIDER_REGISTRATIONS = 'none'
terraform -chdir=TERRAFORM plan `
  -refresh=false `
  -input=false `
  -lock-timeout=30s `
  "-var=group_postfix=<postfix>" `
  "-target=azurerm_public_ip.lab05b"
```

預期只有 `azurerm_public_ip.lab05b` 因 `zones` replacement。這段不保存 plan binary，避免誤套用 `-refresh=false` 的 targeted plan。正式部署前仍須產生 refreshed、無 `-target` 的完整 plan，並檢查 VPN Gateway 及 diagnostic settings 等相依資源。

## M05D: Virtual Hub routing recovery

Virtual Hub 的 ARM `provisioningState=Succeeded` 不代表 Router 已完成。必須同時讀取 `routingState` 與 router IP：

```powershell
$subscriptionId = '<subscription-id>'
$resourceGroup = 'AZ104-<postfix>'
$hubName = 'lab05d-hub03-ea-cat'

az resource show `
  --subscription $subscriptionId `
  --resource-group $resourceGroup `
  --resource-type Microsoft.Network/virtualHubs `
  --name $hubName `
  --query '{id:id,location:location,provisioningState:properties.provisioningState,routingState:properties.routingState,routerIps:properties.virtualRouterIps}' `
  --output json `
  --only-show-errors
```

當 Hub 是 `Succeeded`、Router 是 `Failed` 時，使用官方 Router Reset 原地復原。這是 Azure 與 Terraform state 寫入前的獨立操作關卡；不得將它放進每次 Terraform 執行的自動流程。

### Reset the failed router

先確認唯一且正確的 Azure PowerShell context，並將 Azure Hub 的完整 ID 與目前 Terraform state 硬性比對。以下命令會寫入 Azure，只能在已核准的復原作業中執行：

```powershell
$ErrorActionPreference = 'Stop'
$subscriptionId = '<subscription-id>'
$resourceGroup = 'AZ104-<postfix>'
$hubName = 'lab05d-hub03-ea-cat'
$contexts = @(Get-AzContext -ListAvailable | Where-Object {
  $_.Subscription.Id -eq $subscriptionId
})
if ($contexts.Count -ne 1) {
  throw 'A unique authorized Azure PowerShell context is required.'
}
$azContext = $contexts[0]

$stateLines = @(& terraform '-chdir=TERRAFORM' 'state' 'pull')
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to read the active Terraform state.'
}
$stateJson = $stateLines -join [Environment]::NewLine
$state = $stateJson | ConvertFrom-Json
$stateResources = @($state.resources | Where-Object {
  $_.type -eq 'azurerm_virtual_hub' -and $_.name -eq 'lab05d03'
})
if ($stateResources.Count -ne 1 -or $stateResources[0].instances.Count -ne 1) {
  throw 'Expected exactly one azurerm_virtual_hub.lab05d03 state instance.'
}
$expectedHubId = $stateResources[0].instances[0].attributes.id

$hub = Get-AzVirtualHub `
  -ResourceGroupName $resourceGroup `
  -Name $hubName `
  -DefaultProfile $azContext `
  -ErrorAction Stop

if (-not [string]::Equals(
  $hub.Id,
  $expectedHubId,
  [System.StringComparison]::OrdinalIgnoreCase
)) {
  throw 'Azure Hub ID does not match azurerm_virtual_hub.lab05d03.'
}
if ($hub.ProvisioningState -ne 'Succeeded') {
  throw 'The Virtual Hub is not in Succeeded provisioning state.'
}
if ($hub.RoutingState -eq 'Failed') {
  Reset-AzHubRouter `
    -ResourceGroupName $resourceGroup `
    -Name $hubName `
    -DefaultProfile $azContext `
    -ErrorAction Stop
} elseif ($hub.RoutingState -ne 'Provisioned') {
  throw 'Observe the current routing operation instead of resetting it.'
}

# Router Reset only runs once; subsequent calls are read-only health checks.
$healthyReads = 0
for ($attempt = 1; $attempt -le 60; $attempt++) {
  $hub = Get-AzVirtualHub `
    -ResourceGroupName $resourceGroup `
    -Name $hubName `
    -DefaultProfile $azContext `
    -ErrorAction Stop

  if (-not [string]::Equals(
    $hub.Id,
    $expectedHubId,
    [System.StringComparison]::OrdinalIgnoreCase
  )) {
    throw 'Azure Hub ID changed during router recovery.'
  }
  if ($hub.ProvisioningState -eq 'Failed' -or $hub.RoutingState -eq 'Failed') {
    throw 'Hub/router failed after reset.'
  }

  $routerIps = @($hub.VirtualRouterIps | Where-Object {
    -not [string]::IsNullOrWhiteSpace($_)
  })
  if (
    $hub.ProvisioningState -eq 'Succeeded' -and
    $hub.RoutingState -eq 'Provisioned' -and
    $routerIps.Count -gt 0
  ) {
    $healthyReads++
    if ($healthyReads -eq 2) {
      break
    }
  } else {
    $healthyReads = 0
  }
  Start-Sleep -Seconds 15
}
if ($healthyReads -ne 2) {
  throw 'Router recovery did not satisfy the bounded health check.'
}
```

如果 Router 再次 `Failed` 或逾時，保留 taint、蒐集 Activity Log 的 correlation ID，並停止部署。不要盲目刪除 Hub、搬移區域、調整 SKU 或增加 Terraform timeout。

### Clear taint only after recovery

`untaint` 必須和重新讀取 state、完整 Hub ID 比對、即時健康檢查及備份放在同一個受守衛區塊。以下命令會寫入 Terraform state，只能在已核准且沒有其他 Terraform writer 時執行：

```powershell
$ErrorActionPreference = 'Stop'
$subscriptionId = '<subscription-id>'
$resourceGroup = 'AZ104-<postfix>'
$hubName = 'lab05d-hub03-ea-cat'
$contexts = @(Get-AzContext -ListAvailable | Where-Object {
  $_.Subscription.Id -eq $subscriptionId
})
if ($contexts.Count -ne 1) {
  throw 'A unique authorized Azure PowerShell context is required.'
}
$azContext = $contexts[0]

$stateLines = @(& terraform '-chdir=TERRAFORM' 'state' 'pull')
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to read the active Terraform state.'
}
$stateJson = $stateLines -join [Environment]::NewLine
$state = $stateJson | ConvertFrom-Json
$stateResources = @($state.resources | Where-Object {
  $_.type -eq 'azurerm_virtual_hub' -and $_.name -eq 'lab05d03'
})
if ($stateResources.Count -ne 1 -or $stateResources[0].instances.Count -ne 1) {
  throw 'Expected exactly one azurerm_virtual_hub.lab05d03 state instance.'
}
$stateInstance = $stateResources[0].instances[0]
$expectedHubId = $stateInstance.attributes.id

$healthyReads = 0
for ($attempt = 1; $attempt -le 2; $attempt++) {
  $hub = Get-AzVirtualHub `
    -ResourceGroupName $resourceGroup `
    -Name $hubName `
    -DefaultProfile $azContext `
    -ErrorAction Stop
  $routerIps = @($hub.VirtualRouterIps | Where-Object {
    -not [string]::IsNullOrWhiteSpace($_)
  })
  if (
    -not [string]::Equals(
      $hub.Id,
      $expectedHubId,
      [System.StringComparison]::OrdinalIgnoreCase
    ) -or
    $hub.ProvisioningState -ne 'Succeeded' -or
    $hub.RoutingState -ne 'Provisioned' -or
    $routerIps.Count -eq 0
  ) {
    throw 'Hub identity or routing health does not permit untaint.'
  }
  $healthyReads++
  if ($attempt -lt 2) {
    Start-Sleep -Seconds 15
  }
}
if ($healthyReads -ne 2) {
  throw 'Hub did not pass two consecutive health checks.'
}

if ($stateInstance.status -eq 'tainted') {
  $backupDir = Join-Path $env:USERPROFILE 'az104-backups'
  New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
  $timestamp = Get-Date -Format 'yyyyMMdd-HHmmssfff'
  $backup = Join-Path $backupDir "az104-before-hub-untaint-$timestamp.tfstate"
  if (Test-Path -LiteralPath $backup) {
    throw 'State backup path already exists.'
  }
  Set-Content `
    -LiteralPath $backup `
    -Value $stateJson `
    -NoNewline `
    -Encoding utf8NoBOM
  Get-FileHash -LiteralPath $backup -Algorithm SHA256

  & terraform '-chdir=TERRAFORM' 'untaint' `
    '-lock-timeout=30s' `
    'azurerm_virtual_hub.lab05d03'
  if ($LASTEXITCODE -ne 0) {
    throw 'Terraform untaint failed.'
  }
} elseif ([string]::IsNullOrEmpty($stateInstance.status)) {
  Write-Output 'azurerm_virtual_hub.lab05d03 is already untainted.'
} else {
  throw "Unexpected Terraform state status: $($stateInstance.status)"
}
```

不要使用 `-allow-missing`、`state rm` 或手工編輯 state。

## Full deployment preview

只有在 M05D Router 健康且 state 已不再 tainted 後，才能建立 refreshed、無 `-target` 的完整 plan。這個區塊再次檢查 taint，避免沿用錯誤順序：

```powershell
$ErrorActionPreference = 'Stop'
$stateLines = @(& terraform '-chdir=TERRAFORM' 'state' 'pull')
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to read the active Terraform state.'
}
$state = ($stateLines -join [Environment]::NewLine) | ConvertFrom-Json
$hubInstances = @($state.resources | Where-Object {
  $_.type -eq 'azurerm_virtual_hub' -and $_.name -eq 'lab05d03'
} | ForEach-Object { $_.instances })
if ($hubInstances.Count -ne 1 -or $hubInstances[0].status -eq 'tainted') {
  throw 'Recover and untaint azurerm_virtual_hub.lab05d03 before full planning.'
}

$env:ARM_RESOURCE_PROVIDER_REGISTRATIONS = 'none'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmssfff'
$planPath = Join-Path $env:TEMP "az104-full-$timestamp.tfplan"
& terraform '-chdir=TERRAFORM' 'plan' `
  '-input=false' `
  '-lock-timeout=30s' `
  '-detailed-exitcode' `
  '-var=group_postfix=<postfix>' `
  "-out=$planPath"
$planExitCode = $LASTEXITCODE
if ($planExitCode -notin @(0, 2)) {
  throw "Terraform plan failed with exit code $planExitCode."
}
Write-Output "Review every action in: $planPath"
```

`-detailed-exitcode` 的 `0` 代表沒有差異，`2` 代表 plan 成功且有差異，`1` 代表錯誤。部署前必須檢查所有 create、update、delete 與 replacement；Hub 或 Hub connection replacement 必須中止。不要使用 `-lock=false`，也不要沿用 untaint 前產生的 plan。

如果完整 plan 混入與 M05 復原無關的資源，禁止套用它。只有在已先讀取完整 plan、確認額外差異不屬本次範圍後，才可為這次錯誤復原建立下列 scoped plan：

```powershell
$env:ARM_RESOURCE_PROVIDER_REGISTRATIONS = 'none'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmssfff'
$planPath = Join-Path $env:TEMP "az104-m05-recovery-$timestamp.tfplan"
& terraform '-chdir=TERRAFORM' 'plan' `
  '-input=false' `
  '-lock-timeout=30s' `
  '-detailed-exitcode' `
  '-var=group_postfix=<postfix>' `
  '-target=azurerm_monitor_diagnostic_setting.lab05bpip' `
  '-target=azurerm_monitor_diagnostic_setting.lab05bvnetgw' `
  '-target=azurerm_virtual_hub_connection.lab05d03' `
  "-out=$planPath"
$planExitCode = $LASTEXITCODE
if ($planExitCode -notin @(0, 2)) {
  throw "Terraform plan failed with exit code $planExitCode."
}
Write-Output "Review every action in: $planPath"
```

這是錯誤復原用途的例外，不是日常部署方式。套用前必須確認 scoped plan 只包含：

- `azurerm_public_ip.lab05b`：僅因 `zones` replacement。
- `azurerm_monitor_diagnostic_setting.lab05bpip`：因 Public IP ID 改變而 replacement。
- `azurerm_virtual_network_gateway.lab05b` 與 `azurerm_monitor_diagnostic_setting.lab05bvnetgw`：建立缺少的 Gateway 與診斷設定。
- `azurerm_virtual_hub_connection.lab05d03`：建立缺少的第三條 spoke connection。
- `azurerm_virtual_hub.lab05d03`：只允許原地恢復 `SecurityControl = "Ignore"` tag；不得 replacement。

任何其他位址或 action 都必須停止。只套用剛檢查過且尚未過期的 plan。

## Post-deployment verification

講師部署經過審查的完整 plan 後，至少確認：

- M05B Public IP zones 的集合為 `1,2,3`；順序不重要。
- VPN Gateway 為 `Succeeded`、SKU 是 `VpnGw3AZ`，且引用預期 Public IP。
- Japan East、Japan West、East Asia 三個 Hub 都是 `Succeeded/Provisioned`。
- East Asia Hub 的 router IP 非空。
- 三個 Hub-to-VNet connections 都是 `Succeeded`。
- `azurerm_virtual_hub.lab05d03` 不再 tainted。
- 再次執行 refreshed full plan 時，不再出現本次 Public IP、VPN Gateway、Hub 或第三條 connection 的異常差異。

控制平面通過不等於資料平面通過。如需宣稱環境 demo-ready，仍須確認 VM 運作中、NIC effective routes 正確，並從 spoke VM 測試跨區連線。

## References

- [Create a VPN gateway using Azure CLI](https://learn.microsoft.com/azure/vpn-gateway/create-routebased-vpn-gateway-cli#request-public-ip-addresses)
- [AzureRM 4.78.0 `azurerm_public_ip`](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.78.0/website/docs/r/public_ip.html.markdown)
- [Virtual Hub router reset](https://learn.microsoft.com/azure/virtual-wan/about-virtual-hub-routing#router-reset)
- [`Reset-AzHubRouter`](https://learn.microsoft.com/powershell/module/az.network/reset-azhubrouter?view=azps-16.3.0)
