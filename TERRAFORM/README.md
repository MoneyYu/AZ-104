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

### M08 / M08B subnet NSG 佈局

`lab08-vnet-cat` 的三個 subnet 各自使用不同 NSG，不可合併：

| Subnet | NSG | 對外開放的自訂規則 |
| --- | --- | --- |
| `default` | `lab08-nsg-cat` | `AllowRDP` 3389，來源為 `data.http.myip` 取得的講師公網 IP |
| `AzureBastionSubnet` | `lab08-bastion-nsg-cat` | Azure Bastion 要求的完整輸入/輸出規則 |
| `vmss-subnet` | `lab08b-vmss-nsg-cat` | `AllowHTTP` 80，來源 `*` |

上表只列**自訂**規則。三個 subnet 的 VNet 內部流量一律由預設規則 `AllowVnetInBound` 放行，因此 Bastion 連線與跳板機 RDP 都不需要額外規則。

`default` 的 `AllowRDP` 目前是**示範用途，實際上不會被命中**：`lab08-vm-cat` 的 NIC 沒有 public IP（`lab08-pip-cat` 屬於 Bastion），沒有任何來自 Internet 的路徑能觸及該規則。講師實際是透過 Bastion（443）連線，走的是 `AllowVnetInBound`。保留此規則是為了示範「以來源 IP 限縮 NSG 規則」的寫法；若日後為 VM 加上 public IP，它才會真正生效。

⚠️ 已觀察到 `lab08-nsg-cat` 上的 `AllowRDP` 會被外部程序反覆清除：套用後數十分鐘內規則數會歸零。Activity Log 中沒有出現對應的子層級 `securityRules/delete` 事件，但可以查到針對 `lab08-nsg-cat` 本身的父層級 `Create or Update Network Security Group` 操作紀錄——NSG 規則集合被整批覆寫時，Azure 只會記錄父資源（NSG）的更新事件，不會為其中被移除的子規則各自產生 `securityRules/delete`，這說明了為何看不到規則層級的刪除事件。這項證據**與**「治理自動化移除了來源為 Internet 的 RDP 規則」一致，但**不足以證明**該自動化的實際意圖（例如究竟是刻意的合規修復，還是其他副作用）；請勿將此視為已證實的因果結論。因此 `terraform plan` 會**持續**顯示 `azurerm_network_security_rule.lab08_rdp will be created`。由於上述路徑本來就不會被命中，此漂移**不影響任何示範**，重複 apply 也無法根治；請直接忽略，不要因此判定環境異常。相對地，`lab08b-vmss-nsg-cat` 的 `AllowHTTP` 未受影響——若它變成 0 條規則，M08B 網頁示範就會中斷，屆時才需要重新 apply。

`vmss-subnet` 必須放行 80：`lab08b-lb-cat` 是 public Standard Load Balancer（Tcp 80→80），其輸入流量會保留**原始用戶端來源 IP**（屬 Internet），不會命中 `AllowAzureLoadBalancerInBound` 服務標籤，因此若缺少明確的 80 規則就會被預設規則 `DenyAllInBound` 擋下，VMSS 網頁示範將無法連線。`AllowAzureLoadBalancerInBound` 只涵蓋健康探查，不涵蓋真實用戶端流量。

不要讓 `vmss-subnet` 回頭共用 `lab08-nsg-cat`：該 NSG 只開放 3389，會直接讓 M08B 示範失效。另外，每個 NSG 都要有自己的 `azurerm_monitor_diagnostic_setting`（`NetworkSecurityGroupEvent` 與 `NetworkSecurityGroupRuleCounter`）；新增 NSG 時若漏設，該子網路的 NSG 事件就不會進 Log Analytics。

驗證方式：

```powershell
az network nsg list -g AZ104-<postfix> --query "[].{name:name,rules:length(securityRules)}" -o table
curl.exe -sS -o NUL -w "%{http_code}`n" http://<lab08b-lb-pip>
```

### 政策自動產生的殘留 NSG

租戶政策會為「建立當下未關聯 NSG」的 subnet 自動建立並掛上 NSG，命名為 `<vnet>-<subnet>-nsg-<location>`（0 條規則）。Terraform 隨後套用自己的 `azurerm_subnet_network_security_group_association` 時會覆寫該關聯；之後 `terraform destroy` 刪除 VNet，這些政策 NSG 因**不在 state 內**而殘留。

`terraform destroy` 永遠清不掉它們，必須手動刪除。**先列出候選再刪除**，不要直接對「未關聯」的 NSG 迴圈刪除——Terraform 管理中的 NSG 也可能短暫處於未關聯狀態，或本來就刻意不關聯。候選條件需同時滿足：無 subnet 關聯、無 NIC 關聯、**0 條自訂規則**，且符合政策命名樣式。

```powershell
$rg = 'AZ104-<postfix>'
$candidates = az network nsg list -g $rg -o json |
  ConvertFrom-Json |
  Where-Object {
    -not $_.subnets -and -not $_.networkInterfaces -and
    $_.securityRules.Count -eq 0 -and
    $_.name -match '-nsg-(japaneast|japanwest|eastasia)$'
  }
$candidates | Select-Object name, location | Format-Table   # 先人工核對這份清單
```

確認清單無誤後再刪除：

```powershell
$candidates | ForEach-Object { az network nsg delete -g $rg -n $_.name }
```

此現象最常見於 `TEMP\` 模組 apply 後又 destroy 的備課流程，但根目錄 active 模組同樣採「先建 subnet、再建 association」的兩段式寫法，因此並非完全不會發生。R-1 的取捨是接受偶發殘留並手動清理，而非杜絕它。

## 訂閱／管理群組層級的治理漂移觀察

本環境實際觀察到數項訂閱或管理群組層級的治理控制，會在 apply 之後產生非 Terraform 造成的差異。以下逐項說明觀察結果與因應方式；不是每一項都需要 `ignore_changes`。

### MDE 延伸模組（無 Terraform 漂移）

Microsoft Defender for Endpoint（MDE）的 VM extension 由訂閱層級 Azure Policy 自動部署到所有 VM。此 extension 從未進入任何 `azurerm_virtual_machine_extension` 的 state，`terraform plan` 對它完全無感、也沒有漂移，因此不需要任何 `ignore_changes`。

### Public IP 的 `FirstPartyUsage` ip_tags（既有 ignore 例外）

訂閱政策會自動在每個 Public IP 注入 `FirstPartyUsage` 這個 ip_tag。若不加 `lifecycle { ignore_changes = [ip_tags] }`，每次 `terraform plan` 都會顯示該 Public IP 需要強制重建。本 repo 內所有 `azurerm_public_ip`（含 `TERRAFORM\TEMP\MOD11-deprecated.tf` 的 `lab11`）都已套用此例外。

### AKS Defender 預設 workspace（已顯式宣告，使用窄範圍 ignore）

`azurerm_kubernetes_cluster.lab09c`（`MOD09C.tf`）已於建立時顯式宣告 `microsoft_defender` 區塊，並指向平台既有的 Defender 區域預設 Log Analytics workspace（見下方「Defender 預設 workspace 前置需求」），而不是叢集專屬的 `lab09c-law-cat`。實際 plan 顯示 data source 回傳的 ID 使用 `/resourceGroups/`，但 AKS API/state 儲存為 `/resourcegroups/`；AzureRM 4.78.0 的 resource ID parser 又拒絕小寫路徑段，因此只忽略 `microsoft_defender[0].log_analytics_workspace_id` 的 post-create 大小寫差異。Defender 區塊本身仍由 Terraform 建立與管理。

### lab08 OS-disk SKU 由外部服務主體變更（新增單一 VM 例外）

全訂閱逐台稽核時，只有 `lab08-vm-cat` 的 OS 磁碟直接觀察到 `storage_account_type` 在部署後變成 `Standard_LRS`；其他 8 台 active VM 都維持設定的 `Premium_LRS`，13 台 `TEMP\` VM 尚未部署。訂閱與管理群組層級都查無對應的磁碟 SKU Policy 可解釋 `lab08` 的變更。

⚠️ 特別注意：**`Standard_LRS` 是 Standard HDD，不是 Standard SSD**——Standard SSD 對應的 SKU 名稱是 `StandardSSD_LRS`，兩者不可混淆。

因此只針對 `azurerm_windows_virtual_machine.lab08` 新增：

```hcl
lifecycle {
  ignore_changes = [os_disk[0].storage_account_type]
}
```

設定中的 `storage_account_type` 仍維持 `Premium_LRS` 不變——這是建立時的目標值；只有 `lab08` 建立後被外部程序變更的 SKU 會被忽略。其他 active 與 `TEMP` VM 不套用此例外，Terraform 會繼續偵測它們的 OS disk SKU 差異；若未來真的出現同類 drift，必須先取得該 VM 的 plan、Azure 實況與 Activity Log 證據，再逐台決定是否新增例外。

### VMSS 不套用此例外

`azurerm_windows_virtual_machine_scale_set.lab08vmss`（`MOD08B.tf`）**不**加上述例外。其 model 的 OS 磁碟 SKU 已確認為 `Premium_LRS`，與設定及 state 一致，未出現漂移。

驗證 VMSS 目前的磁碟 SKU 時，必須查詢 **VMSS model**，而不是查詢磁碟資源本身：VMSS 的 OS 磁碟是依 model 動態建立的隱含磁碟，`Get-AzDisk` 無法保證涵蓋這些隱含磁碟。正確作法：

```powershell
(Get-AzVmss -ResourceGroupName AZ104-<postfix> -VMScaleSetName lab08b-vmss-cat).VirtualMachineProfile.StorageProfile.OsDisk.ManagedDisk.StorageAccountType
```

### Apply 前置檢查：涉及 VM/extension 取代時，VM 必須先為執行中狀態

若某次 `terraform plan` 包含 VM 或其 extension 的**取代（replacement）**操作，套用前必須先啟動受影響的 VM，並等待其達到 `VM running` 狀態，才能執行 `terraform apply`；請勿用 `-NoWait` 啟動後就直接 apply。

⚠️ 這項前置步驟只適用於**包含取代操作**的 apply。若 plan 沒有任何 VM/extension replacement，並不需要事先把所有 DR VM 都開機——不要把此步驟誤解為每次一般 apply 都必須先啟動全部 VM。

### Defender 預設 workspace 前置需求

`data.azurerm_log_analytics_workspace.defender_default`（定義於 `MAIN.tf`）指向 Microsoft Defender for Cloud 在 Japan East 為訂閱自動建立的預設 workspace：`DefaultWorkspace-<subscription_id>-EJP`，固定位於資源群組 `DefaultResourceGroup-EJP`。`EJP` 是 Japan East 的區域代碼。若訂閱從未在 Japan East 啟用過 Defender for Cloud（因而從未觸發該 workspace 自動建立），此 data source 會找不到資源，導致 `terraform plan`/`apply` 失敗。套用本環境前，請先確認訂閱在 Japan East 已有 Defender for Cloud 的自動佈建紀錄。

## M05A: VNet peering transit routing (UDR + NVA)

M05A 使用三個 VNet 示範 [VNet peering service chaining](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview#service-chaining)：

- `lab05a-vnet-01-cat`（10.1.0.0/16）是 transit VNet，`lab05a-vm01-cat` 的固定私有 IP `10.1.1.4` 作為 NVA。
- `lab05a-vnet-02-cat`（10.2.0.0/16）是 Japan East spoke。
- `lab05a-vnet-03-cat`（10.3.0.0/16）是 East Asia spoke。

VNet peering **不具傳遞性**。即使 VNet1 分別與 VNet2、VNet3 完成 peering，VNet2 仍不會自動經過 VNet1 到達 VNet3；必須使用 [user-defined routes](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-udr-overview) 將 spoke-to-spoke 流量送到 NVA：

| Route table | Region | Route |
| --- | --- | --- |
| `lab05a-rt-spoke2-cat` | Japan East | `10.3.0.0/16` → `VirtualAppliance` `10.1.1.4` |
| `lab05a-rt-spoke3-cat` | East Asia | `10.2.0.0/16` → `VirtualAppliance` `10.1.1.4` |

VM01 必須同時具備三項條件：私有 IP 固定為 `10.1.1.4`、Azure NIC 已[啟用 IP forwarding](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-network-interface#enable-or-disable-ip-forwarding)，以及客體 OS 的 RRAS routing 已啟用並執行。只開啟 Azure NIC IP forwarding 不會自動讓 Windows 轉送封包。

四個 peering 物件是 VNet1↔VNet2 與 VNet1↔VNet3 的雙向連線；每個方向都必須允許 virtual network access 與 forwarded traffic。Forwarded traffic 允許對端接受來源不是 NVA 本身的轉送封包，但不會讓 peering 變成 transitive，也不會取代 UDR。

兩側 NSG 另有明確的 `10.2.0.0/16`↔`10.3.0.0/16` inbound/outbound allow 規則。流量經 NVA 轉送後，不能依賴 `VirtualNetwork` service tag 自動涵蓋未直接 peering 的遠端 spoke；顯式規則讓資料平面行為可預期。

### Default and validation modes

`lab05a_enable_transit_routing` 是 `bool`，預設為 `false`。基礎部署會建立兩個 route tables 與其中的 routes，但不建立 subnet associations，也不建立任何 peering，讓講師可以從 peering-only 的失敗狀態開始示範。

需要用 Terraform 驗證 association 規劃時，可產生完整 plan 並明確開啟變數：

```powershell
terraform -chdir=TERRAFORM plan `
  "-var=group_postfix=0915" `
  "-var=lab05a_enable_transit_routing=true"
```

這個變數只控制兩個 subnet associations；四個 peering 仍由 demo 腳本手動建立。正式套用前仍須審查完整 plan，不要把 targeted plan 當成可部署的結果。

### Destroy ordering

兩個 route-table associations 都是由 demo 在 Terraform state 外手動建立；當 `lab05a_enable_transit_routing=false` 時，state 中不會有這些 association，這也是本修正的前提。為了讓 destroy 時順序反轉成「先刪 subnet、再刪 route table」，`TEMP\MOD05A.tf` 裡的 subnet 明確加入 `depends_on` route table。

講師在停用或替換 MOD05A、或執行 destroy 前，**建議先跑 demo 的 Reset 區段**，把手動 associations 先清掉再交回 Terraform。若 Azure 在 subnet association 已移除後仍短暫回 `InUseRouteTableCannotBeDeleted`，請直接再跑一次；live validation 曾觀察到 route table 的 reverse `subnets` index 可能延遲更新，這是已觀察到的行為，不是官方保證。

### Manual demo

使用 `DEMO\Module05\05-A-Transit-Routing.ps1`，依區段執行：

1. Preflight 確認目前 Az PowerShell subscription、Resource Group、三個 VNet、兩個 route tables、三台 VM/NIC，以及 VM01 的 `10.1.1.4` 與 NIC IP forwarding。
2. 建立且只建立 VNet1↔VNet2、VNet1↔VNet3 共四個 peering；不要建立 VNet2↔VNet3 peering。
3. 從 VM01 驗證可到兩個 spoke，再從 VM02 驗證 VM03 的 HTTP/ICMP 在 route-table association 前皆失敗。
4. 將 VNet2/default 與 VNet3/default 分別關聯至所在區域的 route table；腳本使用 `Set-AzVirtualNetworkSubnetConfig` 與 `Set-AzVirtualNetwork`，並保留既有 NSG 與 address prefix。
5. 檢查 VM02、VM03 NIC effective routes，應看到 `User`、`Active`、`VirtualAppliance`、next hop `10.1.1.4`，再驗證雙向 HTTP/ICMP 成功。

2026-09-16 曾在 `AZ104-0915` 現場驗證：association 前 VM02→VM03 的 HTTP/ICMP 均為 `False`；association 後 effective routes 與雙向 HTTP/ICMP 符合上述預期；解除 association 後再次為 `False`。這是一次人工 live verification，不是持續執行的自動測試。

### Restore

腳本 Reset 區段會先解除 VNet2/default、VNet3/default 的 route-table associations，再移除本 demo 建立的四個 peering。Reset 可重複執行；預期最終狀態為 peerings 0、associations 0，而兩個 route tables 與 routes 保留。

若先前以 `lab05a_enable_transit_routing=true` 套用 Terraform，請改回 `false` 後產生並審查完整 plan，確保 Terraform state 與上述預設狀態一致。

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

## M06B: Load Balancer 命名與輸出連線

### 子物件改用 LB 前綴命名

`MOD06B.tf` 開頭的 `locals` 集中定義 Load Balancer 的子物件名稱，入口網站與 Network Watcher 的清單因此能直接對應到所屬 LB：

| 子物件 | 名稱 |
| --- | --- |
| Frontend IP configuration | `lab06b-lb-pip-config-cat` |
| Backend pool | `lab06b-lb-bepool-cat` |
| Health probe | `lab06b-lb-probe-cat` |
| Load balancing rule | `lab06b-lb-rule-cat` |
| Outbound rule | `lab06b-lb-outbound-rule-cat` |

Public IP 也一併由 `lab06b-pip-cat` 改名為 `lab06b-lb-pip-cat`。依本 repo 慣例 `domain_name_label` 沿用資源名稱，因此 FQDN 變成 `lab06b-lb-pip-cat.japaneast.cloudapp.azure.com`；舊的講義、書籤或腳本若指向舊 FQDN 必須同步更新。

改名會讓 Public IP 被取代，因此 `lifecycle` 除既有的 `ignore_changes = [ip_tags]` 外，另外需要 `create_before_destroy = true`：取代期間舊的 Public IP 仍被 LB frontend IP configuration 參考，先刪除會被 Azure 拒絕。新舊 DNS label 不同（`lab06b-pip-cat` 與 `lab06b-lb-pip-cat`），兩者短暫並存也不會發生 label 衝突。

### 既有缺陷：後端 VM 沒有輸出連線（已修正）

`azurerm_lb_rule.lab06b` 設定 `disable_outbound_snat = true`，而在本次變更前，環境中既沒有 outbound rule，也沒有 NAT Gateway，VM 更沒有執行個體層級的 public IP。Standard Load Balancer 後端在沒有任何明確輸出設定時預設不得連外，因此兩台 lab06b VM 完全沒有輸出路徑。

實際觀察到的證據：lab06b 兩台 VM 持續執行，但 Log Analytics 連續 30 天沒有任何 `Heartbeat` 資料列；同一工作區的 lab06c VM 則正常回報。

修正方式是新增明確的 `azurerm_lb_outbound_rule.lab06b`（`protocol = "All"`、`allocated_outbound_ports = 1024`、`idle_timeout_in_minutes = 4`，frontend 指向同一個 `lab06b-lb-pip-config-cat`）。這條規則是下列功能的前提，不可為了精簡而刪除：

- Azure Monitor Agent（AMA）回報 `Heartbeat` 與 VM Insights 資料；
- Network Watcher Agent 安裝與回報（`MOD06F.tf` 的兩個 agent extension 因此 `depends_on` 這條 outbound rule）；
- Connection Monitor 的「VM → Internet」測試；
- VM 本身的一般對外存取（例如 Windows Update、下載工具）。

### 部署後驗證

以下指令從 repo 根目錄執行，`AZ104-<postfix>` 換成實際的資源群組：

```powershell
az network lb show -g AZ104-<postfix> -n lab06b-lb-cat `
  --query "{frontend:frontendIPConfigurations[].name,pool:backendAddressPools[].name,probe:probes[].name,rule:loadBalancingRules[].name,outbound:outboundRules[].name}" `
  -o jsonc

az network lb outbound-rule show -g AZ104-<postfix> --lb-name lab06b-lb-cat -n lab06b-lb-outbound-rule-cat `
  --query "{protocol:protocol,allocatedPorts:allocatedOutboundPorts,idleTimeout:idleTimeoutInMinutes,frontend:frontendIPConfigurations[].id}" `
  -o jsonc

az network public-ip show -g AZ104-<postfix> -n lab06b-lb-pip-cat `
  --query "{name:name,fqdn:dnsSettings.fqdn,ip:ipAddress}" `
  -o jsonc
```

確認輸出連線已恢復：AMA 啟動後約 5–10 分鐘，兩台 VM 都應出現在 `Heartbeat` 查詢結果中。

```powershell
$workspaceId = az monitor log-analytics workspace show -g AZ104-<postfix> -n law-vminsights-cat --query customerId -o tsv
az monitor log-analytics query -w $workspaceId --analytics-query "Heartbeat | where TimeGenerated > ago(1h) | where Computer startswith 'lab06b' | summarize LastHeartbeat = max(TimeGenerated) by Computer" -o table
```

`az monitor log-analytics query` 來自 `log-analytics` 擴充功能（`az extension add --name log-analytics`）；也可以直接在入口網站的 Log Analytics 查詢頁面貼上同一段 KQL。

## M06F: Network Watcher（flow log、連線監視、封包擷取）

### 共用的 Network Watcher 不由本環境管理

`MOD06F.tf` 以 `data "azurerm_network_watcher" "japaneast"` 引用訂閱在該區域自動建立的 `NetworkWatcher_japaneast`（位於 `NetworkWatcherRG`）。這是唯讀參考：本環境**不得**建立或刪除該共用 watcher 與其資源群組，`terraform destroy` 也不會移除它。

### 為什麼使用 VNet Flow Logs v2

NSG flow logs 已公告於 2027-09-30 退場，且目前已不再支援新建，因此 demo 一律改用 VNet flow logs：

- https://learn.microsoft.com/azure/network-watcher/nsg-flow-logs-overview
- https://learn.microsoft.com/azure/network-watcher/vnet-flow-logs-overview

### 為什麼使用 `azapi_resource` + 使用者指派的受控識別

- 本環境鎖定的 AzureRM provider 中，`azurerm_network_watcher_flow_log` 只有 `retention_policy`、`traffic_analytics`、`timeouts` 三個區塊，**沒有 `identity`**，無法掛上使用者指派的受控識別（實作當時的 4.78.0 與目前鎖定的 4.81.0 皆是如此）。
- ARM 的 `Microsoft.Network/networkWatchers/flowLogs@2025-07-01` 支援 identity，因此 flow log 改以 `azapi_resource` 建立。
- 儲存體帳戶 `lab06fstorcat` 依租戶政策設定 `shared_access_key_enabled = false`，只接受 Entra ID 驗證。
- UAMI `lab06f-flowlog-mi-cat` 在該儲存體帳戶範圍取得 `Storage Blob Data Contributor`，flow log 以此身分寫入 `insights-logs-flowlogflowevent` 容器；講師帳號另有同一角色，才能在入口網站瀏覽 blob。
- 只有該儲存體資源使用 alias provider `azurerm.storage_no_data_plane`（`features.storage.data_plane_available = false`）。它的唯一作用是讓 provider 略過以 Shared Key 進行的資料平面探測（否則會收到 403 `KeyBasedAuthenticationNotPermitted`）。**這不代表**管理平面不會呼叫 `ListKeys`，也不代表 state 內不會出現機密；Terraform state 仍須當成機密資料保護。

### Packet Capture 只寫入 VM 本機

Network Watcher 封包擷取若要直接寫入儲存體，只支援 SAS 或 Shared Key，而本模組的儲存體帳戶已停用 Shared Key。因此 `.\DEMO\Module06\NW-PacketCapture.ps1` 刻意只把 `.cap` 寫到 VM 本機路徑（預設 `C:\CaptureLogs\lab06b-http-capture.cap`），而且不下載該檔案。**不要**為了這個 demo 放寬儲存體政策去重新啟用 Shared Key；需要取回檔案時，改以 Azure Bastion 連線複製，或另外安排以 Entra ID 驗證的傳輸（例如對具備資料平面 RBAC 的帳戶使用 AzCopy 登入模式）。

```powershell
.\DEMO\Module06\NW-PacketCapture.ps1 -ResourceGroup AZ104-<postfix>
```

腳本會啟動擷取、從 VM 內部產生 HTTP 流量、停止擷取，並回報 `.cap` 的位置與大小；預設目標為 `lab06b-vm01-cat`、對端為 `lab06b-vm02-cat`，可用 `-VmName` / `-PeerVmName` / `-CaptureFilePath` 等參數覆寫。重跑前先刪除同名 session：

```powershell
az network watcher packet-capture delete --location japaneast --name lab06b-http-capture
```

### Connection Monitor 測試矩陣

`azurerm_network_connection_monitor.lab06f`（名稱 `lab06f-connection-monitor-cat`）的三個 test group，測試頻率皆為 60 秒：

| Test group | 來源 | 目的地 | 測試 |
| --- | --- | --- | --- |
| `vm-to-vm` | `lab06b-vm01-cat` | `lab06b-vm02-cat` | TCP 80、ICMP（啟用 trace route） |
| `vm-to-appgw` | `lab06b-vm01-cat`、`lab06b-vm02-cat` | M06C App Gateway 公用 FQDN（`lab06c-pip-cat.japaneast.cloudapp.azure.com`） | TCP 80 |
| `vm-to-internet` | `lab06b-vm01-cat` | `www.microsoft.com` | TCP 443 |

前提條件：

- ICMP 測試需要 VM 開啟 Windows 防火牆規則 `FPS-ICMP4-ERQ-In`，由 `MOD06B.tf` 的 CustomScriptExtension 在佈建時啟用；若手動重建 VM 而未跑該腳本，ICMP 測試會失敗。
- 所有測試都依賴 M06B 的明確 outbound rule，Network Watcher Agent 也因此設定 `depends_on`。

### 跨模組相依

`MOD06F.tf` 同時參考 MOD06B（VNet、兩台 VM）與 MOD06C（App Gateway 的 public IP FQDN）。若要把模組搬進或搬出 `TEMP\`，**B、C、F 三者必須一起移動**，否則參考會中斷而無法 plan。

### Traffic Analytics 與清理注意事項

flow log 啟用 Traffic Analytics（`trafficAnalyticsInterval = 10` 分鐘、保留 7 天、format JSON v2），資料送往共用工作區 `law-vminsights-cat`。Azure 會在**工作區所在資源群組**（本環境為 `AZ104-<postfix>`）自動建立 `NWTA` 前綴的 DCR/DCE。

這些 DCR/DCE 由 Traffic Analytics 服務自行建立與管理，不在 Terraform state 內，所以 `terraform destroy` 不會直接對它們下刪除。但**不在 state 內不代表沒有人會清**：[Network Watcher FAQ](https://learn.microsoft.com/azure/network-watcher/frequently-asked-questions#can-i-apply-locks-to-the-dce-and-dcr-resources-created-by-traffic-analytics--) 寫明「Locked resources aren't cleaned up upon deletion of the related flow logs」，可見服務本身的清理時機是**相關 flow log 被刪除時**，而 resource lock 會擋掉這個清理。FAQ 並未保證未上鎖的資源一定會被清乾淨，所以刪完 flow log 之後仍要實際檢查有無殘留。同一份 FAQ 也說明對這些資源做任何操作都可能讓 Traffic Analytics 無法正常運作，因此順序很重要。

拆除環境時照下列順序走，不要反過來：

1. **先辨識相依**：確認有哪些 flow log 正在使用這組 NWTA DCR/DCE。工作區是共用的，同一組 DCR/DCE 可能同時服務其他 flow log（其他模組或其他講師的環境），這種情況下它們就不屬於本環境。
2. **先停用或刪除對應的 flow log**：本環境是 `lab06f-vnet-flowlog-cat`，交給 `terraform destroy` 處理該 azapi 資源即可；手動處理時用 `az network watcher flow-log delete --location japaneast --name lab06f-vnet-flowlog-cat`。
3. **flow log 移除後才回頭檢查殘留**：給服務一點時間，再列出工作區所在資源群組內的 `NWTA` 資源。
4. **只手動刪除「已確認未被使用、且屬於本環境」的殘留**：若殘留還在，先確認是不是被 resource lock 擋住（服務不會清理被鎖住的資源，這也是不建議對這些 DCR/DCE 上鎖的原因）；確定無人使用後才移除。

```powershell
# 步驟 3：flow log 已刪除之後才執行
az resource list -g AZ104-<postfix> `
  --query "[?starts_with(name,'NWTA')].{name:name,type:type,location:location}" -o table

# 步驟 4：殘留仍在時，先確認有沒有鎖
az lock list -g AZ104-<postfix> -o table
```

**絕對不要**：在 flow log 還在使用時就先刪 DCR/DCE（會讓 Traffic Analytics 失效）、整組刪除 `NetworkWatcherRG`，或刪除與本環境無關的 monitor 資源（其他講師或其他環境可能共用同一區域的 watcher 與同一個工作區）。

成本備註：Flow logs 每個訂閱每月有 5 GB 免費額度；Traffic Analytics **沒有**免費額度，依處理量計費。10 分鐘間隔是為了課堂上較快看到資料而選，不是成本最佳化的設定；長時間掛著環境時要留意費用。

### 部署前後驗證

部署前先確認共用 watcher 存在，且該區域尚無同名 flow log：

```powershell
az network watcher list --query "[?location=='japaneast'].{name:name,rg:resourceGroup,state:provisioningState}" -o table
az network watcher flow-log list --location japaneast --query "[].{name:name,target:targetResourceId,enabled:enabled}" -o table
```

部署後檢查 flow log、Traffic Analytics、身分識別、儲存體政策與 Connection Monitor：

```powershell
az network watcher flow-log show --location japaneast --name lab06f-vnet-flowlog-cat `
  --query "{enabled:enabled,target:targetResourceId,version:format.version,retentionDays:retentionPolicy.days,ta:flowAnalyticsConfiguration.networkWatcherFlowAnalyticsConfiguration.enabled,taInterval:flowAnalyticsConfiguration.networkWatcherFlowAnalyticsConfiguration.trafficAnalyticsInterval,identity:identity.type}" `
  -o jsonc

az storage account show -g AZ104-<postfix> -n lab06fstorcat `
  --query "{sharedKey:allowSharedKeyAccess,oauthDefault:defaultToOAuthAuthentication,https:enableHttpsTrafficOnly}" `
  -o jsonc

az network watcher connection-monitor show --location japaneast --name lab06f-connection-monitor-cat `
  --query "{provisioning:provisioningState,groups:testGroups[].{name:name,sources:sources,destinations:destinations,tests:testConfigurations}}" `
  -o jsonc
```

資料平面（實際有沒有進資料）只能用 KQL 確認，工作區 GUID 取得方式同 M06B：

```kusto
// Connection Monitor 測試結果（部署後約 5–10 分鐘開始有資料）
NWConnectionMonitorTestResult
| where TimeGenerated > ago(1h)
| summarize Tests = count(), Failed = countif(TestResult !~ "Pass") by TestGroupName, DestinationName
| order by TestGroupName asc

// VNet flow logs + Traffic Analytics（間隔 10 分鐘，通常 20–30 分鐘後才穩定出現）
// SubType 的實際值為 "Flowlog"，這裡用大小寫不敏感的 =~ 比對避免拼寫踩雷
// NTANetAnalytics 存的是彙總後的紀錄，count() 算的是「紀錄筆數」而不是流量數，因此欄位命名為 Records
NTANetAnalytics
| where TimeGenerated > ago(2h)
| where SubType =~ "FlowLog"
| summarize Records = count() by FlowStatus, DestPort
| order by Records desc

// 後端 VM 是否恢復回報（驗證 M06B outbound rule）
Heartbeat
| where TimeGenerated > ago(1h)
| where Computer startswith "lab06b"
| summarize LastHeartbeat = max(TimeGenerated) by Computer
```

**注意**：`terraform validate` 與 `terraform plan` 只能驗證設定與控制平面變更，無法證明 flow log、Traffic Analytics 或 Connection Monitor 真的有資料進入工作區。上課前務必實際跑過上述 KQL 與 `NW-PacketCapture.ps1`，確認資料平面正常。

## M06C: Application Gateway path-based routing

M06C 以 Contoso 線上媒體商店示範 Application Gateway 如何先依 URL path 選擇 backend pool，再於選定的 pool 內執行負載平衡。

| Request path | Backend pool / target | 示範重點 |
| --- | --- | --- |
| `/` | default pool：vm01 + vm02 | 多次要求會在 pool 內負載平衡 |
| `/images/*` | vm03 | backend 保留並收到 `/images/*`，未設定 path override |
| `/video/*` | vm04 | backend 收到 `/`，刻意設定 path override |
| `/legacy/*` | `/` | 永久重新導向至根路徑 |

`/images/*` 與 `/video/*` 的差異是刻意安排：images 的 backend HTTP settings 不覆寫 path，因此 IIS 收到原始 `/images/*`；video 的 settings 將 path 覆寫為 `/`，因此 vm04 以網站根目錄內容回應。Path-based routing 決定要進入哪個 pool；若 pool 內有多個健康成員（例如 default pool 的 vm01 與 vm02），才會在該 pool 內進行負載平衡。

Backend 成員是透過 NIC association 加入 pool，不是直接寫在 Application Gateway 的 `backend_address_pool` block。部署後，Azure CLI 應在 `backendIPConfigurations` 顯示成員，`backendAddresses` 則為空：

```powershell
az network application-gateway show -g AZ104-<postfix> -n lab06c-appgw-cat --query "backendAddressPools[].{name:name,ipcfg:length(backendIPConfigurations),addr:length(backendAddresses)}" -o table
```

檢閱 `azurerm_application_gateway.lab06c` 的 Terraform plan 時，注意 provider 將 gateway 的巢狀 blocks 視為 Sets；即使實際只修改其中一部分，文字輸出也可能看起來像整個 block 被移除後重新加入。Gateway 必須顯示為 `~ update in-place`，不可出現 `-/+ destroy and then create replacement`。逐項核對 backend pools、HTTP settings、probes、path rules 與 redirect，不能只依增刪行數判斷風險。

### Post-deployment validation

從 repo 根目錄執行完整講師腳本，確認 root pool 的 vm01/vm02 回應、images、video、legacy redirect 與 backend health：

```powershell
.\DEMO\Module06\AGW-PathRouting.ps1 -ResourceGroup AZ104-<postfix>
```

也可以逐項檢查資料平面路由：

```powershell
$fqdn = az network public-ip show -g AZ104-<postfix> -n lab06c-pip-cat --query "dnsSettings.fqdn" -o tsv
curl.exe -fsS "http://$fqdn/"
curl.exe -fsS "http://$fqdn/images/"
curl.exe -fsS "http://$fqdn/video/"
curl.exe -sS -o NUL -w "HTTP %{http_code}; redirect %{redirect_url}`n" "http://$fqdn/legacy/"

az network application-gateway show-backend-health `
  -g AZ104-<postfix> `
  -n lab06c-appgw-cat `
  --query "backendAddressPools[].{pool:backendAddressPool.id,servers:backendHttpSettingsCollection[].servers[].{address:address,health:health}}" `
  -o jsonc
```

`terraform validate` 與 `terraform plan` 只能驗證設定及控制平面變更，不能證明實際 routing 行為。完成部署後仍必須執行上述 data-plane HTTP checks，確認回應內容、301 redirect target 與 backend health。

### NSG 規則相依性與銷毀順序 (Destroy ordering)

Application Gateway v2 要求其所在子網路的 NSG 必須開放 `GatewayManager` 的輸入流量（TCP 65200-65535）。當 Application Gateway 仍存在於子網路時，Azure 控制平面會拒絕移除該 NSG 規則。

若 NSG 規則以獨立的 `azurerm_network_security_rule` 資源定義，在未設定顯式相依性的情況下，Terraform 在執行銷毀（destroy）時會將這些獨立規則視為葉節點並過早刪除，導致 `ApplicationGatewaySubnetInboundTrafficBlockedByNetworkSecurityGroup` 錯誤。

因此在 `azurerm_application_gateway.lab06c` 中加入顯式 `depends_on` 指向四條 NSG 規則（`lab06cagw_http`、`lab06cagw_https`、`lab06cagw_gwmgr`、`lab06cagw_lb`）：
- **建立（Create）時**：強制先建立 NSG 規則，再建立 Application Gateway。
- **銷毀（Destroy）時**：強制先刪除 Application Gateway，再刪除 NSG 規則。

**注意**：相依性方向不可反轉（不可在 NSG 規則上加上對 Application Gateway 的依賴，否則會導致銷毀順序顛倒）。

詳細資訊與官方需求請參考：
https://learn.microsoft.com/en-us/azure/application-gateway/configuration-infrastructure

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
