# ============================================================================
# M04 - Azure Private DNS 示範
# ----------------------------------------------------------------------------
# 情境（對應 TERRAFORM/MOD04B.tf）：
#   私人 DNS 區域：corp.contoso.com
#   VNet-A（已連結、啟用自動註冊）內含 vm-a1、vm-a2
#   VNet-B（未連結）內含 vm-b1
#   手動 A 記錄：app.corp.contoso.com -> 10.40.1.100
#
# 教學重點：
#   1. 同一個「已連結」VNet 內的 VM 會自動註冊，且可用名稱互相解析
#   2. 「未連結」的 VNet 無法解析私人區域中的記錄
#   3. 為 VNet-B 加上「僅解析」連結後，vm-b1 即可解析（但自己不會被自動註冊）
#   4. 私人區域的名稱解析「不需要」VNet 對等互連（peering）
#   5. 關鍵：VM 必須使用 Azure 預設 DNS（168.63.129.16）才能解析私人區域；
#      lab04 防火牆 VM 因設定 dns_servers=8.8.8.8 故無法解析（所以才獨立出本範例）
# ============================================================================

$rg   = "AZ104-<group_postfix>"   # 換成你的資源群組（group_postfix）
$zone = "corp.contoso.com"

# --- 1. 檢視私人 DNS 區域中的記錄（含 vm-a1 / vm-a2 自動註冊的 A 記錄）---
Get-AzPrivateDnsRecordSet -ResourceGroupName $rg -ZoneName $zone |
  Select-Object Name, RecordType, @{n = 'Records'; e = { $_.Records.Ipv4Address -join ',' } }

# --- 2. 在 vm-a1 上（RDP 進入後於命令列執行）---
#   nslookup vm-a2.corp.contoso.com      # 解析成功 -> 10.40.1.x
#   nslookup app.corp.contoso.com        # 解析成功 -> 10.40.1.100

# --- 3. 在 vm-b1 上（RDP 進入後於命令列執行）---
#   nslookup vm-a1.corp.contoso.com      # 失敗（NXDOMAIN）：VNet-B 尚未連結到區域
#   nslookup app.corp.contoso.com        # 失敗（NXDOMAIN）

# --- 4. 現場為 VNet-B 加上「僅解析」連結（不啟用自動註冊）---
$vnetB = Get-AzVirtualNetwork -ResourceGroupName $rg -Name "lab04b-vnet-b-cat"
New-AzPrivateDnsVirtualNetworkLink `
  -ResourceGroupName $rg `
  -ZoneName $zone `
  -Name "link-b" `
  -VirtualNetworkId $vnetB.Id
# 注意：未加 -EnableRegistration，因此 VNet-B 只能「解析」、不會「自動註冊」

# --- 5. 回到 vm-b1 重新測試 ---
#   nslookup vm-a1.corp.contoso.com      # 現在解析成功
#   nslookup app.corp.contoso.com        # 現在解析成功
#   （但 vm-b1 自己不會出現在區域記錄中，因為此連結未啟用註冊）

# --- 清除現場新增的連結（選用，方便重複示範）---
# Remove-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $rg -ZoneName $zone -Name "link-b"
