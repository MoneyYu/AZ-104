<#
.SYNOPSIS
    Demonstrates M05A VNet peering transit routing through VM01.

.DESCRIPTION
    Run the sections in order during the demo. The base Terraform deployment
    keeps the two route tables unassociated and creates no VNet peerings.

.PARAMETER GroupPostfix
    The Terraform group_postfix value. The resource group is AZ104-<postfix>.

.PARAMETER RandomString
    The resource-name suffix used by the Terraform environment.

.EXAMPLE
    .\DEMO\Module05\05-A-Transit-Routing.ps1

.EXAMPLE
    .\DEMO\Module05\05-A-Transit-Routing.ps1 -GroupPostfix 0915 -RandomString cat
#>
param(
    [ValidateNotNullOrEmpty()]
    [string]$GroupPostfix = "0915",

    [ValidateNotNullOrEmpty()]
    [string]$RandomString = "cat"
)

$ErrorActionPreference = "Stop"

$resourceGroup = "AZ104-$GroupPostfix"
$subnetName = "default"
$vnet1Name = "lab05a-vnet-01-$RandomString"
$vnet2Name = "lab05a-vnet-02-$RandomString"
$vnet3Name = "lab05a-vnet-03-$RandomString"
$vm1Name = "lab05a-vm01-$RandomString"
$vm2Name = "lab05a-vm02-$RandomString"
$vm3Name = "lab05a-vm03-$RandomString"
$nic1Name = "lab05a-nic-01-$RandomString"
$nic2Name = "lab05a-nic-02-$RandomString"
$nic3Name = "lab05a-nic-03-$RandomString"
$routeTable2Name = "lab05a-rt-spoke2-$RandomString"
$routeTable3Name = "lab05a-rt-spoke3-$RandomString"

$peeringDefinitions = @(
    [pscustomobject]@{
        Name       = "lab05a-vnet1-to-vnet2"
        SourceVNet = $vnet1Name
        RemoteVNet = $vnet2Name
    }
    [pscustomobject]@{
        Name       = "lab05a-vnet2-to-vnet1"
        SourceVNet = $vnet2Name
        RemoteVNet = $vnet1Name
    }
    [pscustomobject]@{
        Name       = "lab05a-vnet1-to-vnet3"
        SourceVNet = $vnet1Name
        RemoteVNet = $vnet3Name
    }
    [pscustomobject]@{
        Name       = "lab05a-vnet3-to-vnet1"
        SourceVNet = $vnet3Name
        RemoteVNet = $vnet1Name
    }
)

function Write-Section {
    param([string]$Title)
    Write-Host "`n========== $Title ==========" -ForegroundColor Cyan
}

function Get-SubnetAddressPrefixes {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Subnet
    )

    $prefixes = @($Subnet.AddressPrefix | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_)
    })
    if ($prefixes.Count -eq 0) {
        $prefixes = @($Subnet.AddressPrefixes | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        })
    }
    if ($prefixes.Count -eq 0) {
        throw "Subnet '$($Subnet.Name)' does not have an address prefix."
    }

    return $prefixes
}

function Get-SubnetNetworkSecurityGroup {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Subnet
    )

    if (
        $null -eq $Subnet.NetworkSecurityGroup -or
        [string]::IsNullOrWhiteSpace($Subnet.NetworkSecurityGroup.Id)
    ) {
        return $null
    }

    $nsgName = $Subnet.NetworkSecurityGroup.Id.Split("/")[-1]
    return Get-AzNetworkSecurityGroup `
        -ResourceGroupName $resourceGroup `
        -Name $nsgName `
        -ErrorAction Stop
}

function Add-DemoPeering {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Definition
    )

    $existing = Get-AzVirtualNetworkPeering `
        -ResourceGroupName $resourceGroup `
        -VirtualNetworkName $Definition.SourceVNet `
        -Name $Definition.Name `
        -ErrorAction SilentlyContinue
    if ($null -ne $existing) {
        Write-Host "Peering already exists: $($Definition.Name)"
        return
    }

    $sourceVNet = Get-AzVirtualNetwork `
        -ResourceGroupName $resourceGroup `
        -Name $Definition.SourceVNet `
        -ErrorAction Stop
    $remoteVNet = Get-AzVirtualNetwork `
        -ResourceGroupName $resourceGroup `
        -Name $Definition.RemoteVNet `
        -ErrorAction Stop

    # Az.Network enables virtual network access by default; do not use -BlockVirtualNetworkAccess.
    $peering = Add-AzVirtualNetworkPeering `
        -VirtualNetwork $sourceVNet `
        -Name $Definition.Name `
        -RemoteVirtualNetworkId $remoteVNet.Id `
        -AllowForwardedTraffic `
        -ErrorAction Stop
    if (-not $peering.AllowVirtualNetworkAccess -or -not $peering.AllowForwardedTraffic) {
        throw "Peering '$($Definition.Name)' does not allow virtual network access and forwarded traffic."
    }
}

function Set-DemoSubnetRouteTable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VirtualNetworkName,

        [Parameter(Mandatory = $true)]
        [object]$RouteTable
    )

    $virtualNetwork = Get-AzVirtualNetwork `
        -ResourceGroupName $resourceGroup `
        -Name $VirtualNetworkName `
        -ErrorAction Stop
    $subnet = Get-AzVirtualNetworkSubnetConfig `
        -Name $subnetName `
        -VirtualNetwork $virtualNetwork `
        -ErrorAction Stop
    $addressPrefixes = Get-SubnetAddressPrefixes -Subnet $subnet
    $networkSecurityGroup = Get-SubnetNetworkSecurityGroup -Subnet $subnet

    $subnetParameters = @{
        Name           = $subnetName
        VirtualNetwork = $virtualNetwork
        AddressPrefix  = $addressPrefixes
        RouteTable     = $RouteTable
        ErrorAction    = "Stop"
    }
    if ($null -ne $networkSecurityGroup) {
        $subnetParameters.NetworkSecurityGroup = $networkSecurityGroup
    }

    Set-AzVirtualNetworkSubnetConfig @subnetParameters | Out-Null
    Set-AzVirtualNetwork `
        -VirtualNetwork $virtualNetwork `
        -ErrorAction Stop | Out-Null
}

function Remove-DemoSubnetRouteTable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VirtualNetworkName
    )

    $virtualNetwork = Get-AzVirtualNetwork `
        -ResourceGroupName $resourceGroup `
        -Name $VirtualNetworkName `
        -ErrorAction Stop
    $subnet = Get-AzVirtualNetworkSubnetConfig `
        -Name $subnetName `
        -VirtualNetwork $virtualNetwork `
        -ErrorAction Stop

    if (
        $null -eq $subnet.RouteTable -or
        [string]::IsNullOrWhiteSpace($subnet.RouteTable.Id)
    ) {
        Write-Host "$VirtualNetworkName/$subnetName already has no route-table association."
        return
    }

    # Clearing only RouteTable on the existing subnet object preserves its NSG and address prefixes.
    $subnet.RouteTable = $null
    Set-AzVirtualNetwork `
        -VirtualNetwork $virtualNetwork `
        -ErrorAction Stop | Out-Null
}

function Invoke-DemoConnectivityTest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceVmName,

        [Parameter(Mandatory = $true)]
        [string]$TargetIp,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedResult
    )

    Write-Host "`n$SourceVmName -> $TargetIp (expected: $ExpectedResult)" -ForegroundColor Yellow
    $testScript = @"
`$target = '$TargetIp'
[pscustomobject]@{
    Source = `$env:COMPUTERNAME
    Target = `$target
    HTTP   = Test-NetConnection -ComputerName `$target -Port 80 -InformationLevel Quiet -WarningAction SilentlyContinue
    ICMP   = Test-Connection -ComputerName `$target -Count 2 -Quiet
} | Format-List | Out-String
"@

    $result = Invoke-AzVMRunCommand `
        -ResourceGroupName $resourceGroup `
        -VMName $SourceVmName `
        -CommandId "RunPowerShellScript" `
        -ScriptString $testScript `
        -ErrorAction Stop
    $result.Value | ForEach-Object { Write-Host $_.Message }
}

## 階段 0：確認訂閱、資源群組與既有拓撲
Write-Section "階段 0：Preflight"

$context = Get-AzContext
if ($null -eq $context -or $null -eq $context.Subscription) {
    throw "No Azure PowerShell context is selected. Run Connect-AzAccount and Set-AzContext first."
}

$resourceGroupObject = Get-AzResourceGroup `
    -Name $resourceGroup `
    -ErrorAction Stop

$vnet1 = Get-AzVirtualNetwork -ResourceGroupName $resourceGroup -Name $vnet1Name -ErrorAction Stop
$vnet2 = Get-AzVirtualNetwork -ResourceGroupName $resourceGroup -Name $vnet2Name -ErrorAction Stop
$vnet3 = Get-AzVirtualNetwork -ResourceGroupName $resourceGroup -Name $vnet3Name -ErrorAction Stop
$routeTable2 = Get-AzRouteTable -ResourceGroupName $resourceGroup -Name $routeTable2Name -ErrorAction Stop
$routeTable3 = Get-AzRouteTable -ResourceGroupName $resourceGroup -Name $routeTable3Name -ErrorAction Stop
$nic1 = Get-AzNetworkInterface -ResourceGroupName $resourceGroup -Name $nic1Name -ErrorAction Stop
$nic2 = Get-AzNetworkInterface -ResourceGroupName $resourceGroup -Name $nic2Name -ErrorAction Stop
$nic3 = Get-AzNetworkInterface -ResourceGroupName $resourceGroup -Name $nic3Name -ErrorAction Stop
Get-AzVM -ResourceGroupName $resourceGroup -Name $vm1Name -ErrorAction Stop | Out-Null
Get-AzVM -ResourceGroupName $resourceGroup -Name $vm2Name -ErrorAction Stop | Out-Null
Get-AzVM -ResourceGroupName $resourceGroup -Name $vm3Name -ErrorAction Stop | Out-Null

$vm1Ip = ($nic1.IpConfigurations | Select-Object -First 1).PrivateIpAddress
$vm2Ip = ($nic2.IpConfigurations | Select-Object -First 1).PrivateIpAddress
$vm3Ip = ($nic3.IpConfigurations | Select-Object -First 1).PrivateIpAddress
if ($vm1Ip -ne "10.1.1.4") {
    throw "VM01 must use static private IP 10.1.1.4, but the NIC reports '$vm1Ip'."
}
if (-not $nic1.EnableIPForwarding) {
    throw "NIC '$nic1Name' must have Azure IP forwarding enabled."
}

$expectedRoute2 = $routeTable2.Routes | Where-Object {
    $_.AddressPrefix -eq "10.3.0.0/16" -and
    $_.NextHopType -eq "VirtualAppliance" -and
    $_.NextHopIpAddress -eq "10.1.1.4"
}
$expectedRoute3 = $routeTable3.Routes | Where-Object {
    $_.AddressPrefix -eq "10.2.0.0/16" -and
    $_.NextHopType -eq "VirtualAppliance" -and
    $_.NextHopIpAddress -eq "10.1.1.4"
}
if ($null -eq $expectedRoute2 -or $null -eq $expectedRoute3) {
    throw "The expected spoke-to-spoke routes through 10.1.1.4 are missing."
}

Write-Host "Subscription  : $($context.Subscription.Name) ($($context.Subscription.Id))"
Write-Host "Resource group: $($resourceGroupObject.ResourceGroupName)"
Write-Host "Location      : $($resourceGroupObject.Location)"
@(
    [pscustomobject]@{ VM = $vm1Name; NIC = $nic1Name; PrivateIp = $vm1Ip; Role = "NVA" }
    [pscustomobject]@{ VM = $vm2Name; NIC = $nic2Name; PrivateIp = $vm2Ip; Role = "Spoke 2" }
    [pscustomobject]@{ VM = $vm3Name; NIC = $nic3Name; PrivateIp = $vm3Ip; Role = "Spoke 3" }
) | Format-Table -AutoSize
@($routeTable2, $routeTable3) |
    Select-Object Name, Location, @{ Name = "AssociatedSubnets"; Expression = { @($_.Subnets).Count } } |
    Format-Table -AutoSize

$spoke2Subnet = Get-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet2
$spoke3Subnet = Get-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet3
if (
    -not [string]::IsNullOrWhiteSpace($spoke2Subnet.RouteTable.Id) -or
    -not [string]::IsNullOrWhiteSpace($spoke3Subnet.RouteTable.Id)
) {
    Write-Warning "Stage 1 expects both spoke route tables to be unassociated. Run the reset section first."
}

## 階段 1：建立四個 Hub-to-Spoke peering
## 警告：以下區塊會建立 Azure VNet peering。VNet2 與 VNet3 之間不建立直接 peering。
Write-Section "階段 1：建立四個 peering"

$peeringDefinitions | ForEach-Object { Add-DemoPeering -Definition $_ }

$peeringDefinitions | ForEach-Object {
    Get-AzVirtualNetworkPeering `
        -ResourceGroupName $resourceGroup `
        -VirtualNetworkName $_.SourceVNet `
        -Name $_.Name `
        -ErrorAction Stop
} | Select-Object Name, PeeringState, AllowVirtualNetworkAccess, AllowForwardedTraffic |
    Format-Table -AutoSize

## 階段 1 測試：VM01 可到兩個 spoke，但 peering 本身不會讓 spoke-to-spoke 傳遞
Write-Section "階段 1：Peering-only 連線測試"

Invoke-DemoConnectivityTest -SourceVmName $vm1Name -TargetIp $vm2Ip -ExpectedResult "HTTP=True, ICMP=True"
Invoke-DemoConnectivityTest -SourceVmName $vm1Name -TargetIp $vm3Ip -ExpectedResult "HTTP=True, ICMP=True"
Invoke-DemoConnectivityTest -SourceVmName $vm2Name -TargetIp $vm3Ip -ExpectedResult "HTTP=False, ICMP=False"

## 階段 2：將 spoke subnet 關聯至各區域的 route table
## Azure portal：Route tables > Subnets > Associate，分別選取 VNet2/default 與 VNet3/default。
## 警告：以下區塊會變更兩個 subnet。Set-AzVirtualNetworkSubnetConfig 會保留原 NSG 與 address prefix。
Write-Section "階段 2：關聯 route tables"

Set-DemoSubnetRouteTable -VirtualNetworkName $vnet2Name -RouteTable $routeTable2
Set-DemoSubnetRouteTable -VirtualNetworkName $vnet3Name -RouteTable $routeTable3

@($vnet2Name, $vnet3Name) | ForEach-Object {
    $virtualNetwork = Get-AzVirtualNetwork -ResourceGroupName $resourceGroup -Name $_
    $subnet = Get-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $virtualNetwork
    [pscustomobject]@{
        VirtualNetwork = $_
        Subnet         = $subnet.Name
        RouteTable     = $subnet.RouteTable.Id.Split("/")[-1]
        NSG            = $subnet.NetworkSecurityGroup.Id.Split("/")[-1]
        AddressPrefix  = (Get-SubnetAddressPrefixes -Subnet $subnet) -join ", "
    }
} | Format-Table -AutoSize

## 階段 2 測試：NIC effective routes 應顯示 User/Active/VirtualAppliance/10.1.1.4
Write-Section "階段 2：Effective routes"

Get-AzEffectiveRouteTable `
    -ResourceGroupName $resourceGroup `
    -NetworkInterfaceName $nic2Name `
    -ErrorAction Stop |
    Where-Object { $_.Source -eq "User" } |
    Select-Object Name, Source, State, AddressPrefix, NextHopType, NextHopIpAddress |
    Format-Table -AutoSize

Get-AzEffectiveRouteTable `
    -ResourceGroupName $resourceGroup `
    -NetworkInterfaceName $nic3Name `
    -ErrorAction Stop |
    Where-Object { $_.Source -eq "User" } |
    Select-Object Name, Source, State, AddressPrefix, NextHopType, NextHopIpAddress |
    Format-Table -AutoSize

Write-Section "階段 2：Spoke-to-spoke 雙向測試"

Invoke-DemoConnectivityTest -SourceVmName $vm2Name -TargetIp $vm3Ip -ExpectedResult "HTTP=True, ICMP=True"
Invoke-DemoConnectivityTest -SourceVmName $vm3Name -TargetIp $vm2Ip -ExpectedResult "HTTP=True, ICMP=True"

## Reset：先解除兩個 route-table association，再移除且只移除本 demo 建立的四個 peering
## 警告：以下區塊會變更 Azure。Route tables 與其中的 routes 會保留。
Write-Section "Reset：恢復 Terraform 預設狀態"

Remove-DemoSubnetRouteTable -VirtualNetworkName $vnet2Name
Remove-DemoSubnetRouteTable -VirtualNetworkName $vnet3Name

$peeringDefinitions | ForEach-Object {
    $existing = Get-AzVirtualNetworkPeering `
        -ResourceGroupName $resourceGroup `
        -VirtualNetworkName $_.SourceVNet `
        -Name $_.Name `
        -ErrorAction SilentlyContinue
    if ($null -eq $existing) {
        Write-Host "Peering already absent: $($_.Name)"
        return
    }

    Remove-AzVirtualNetworkPeering `
        -ResourceGroupName $resourceGroup `
        -VirtualNetworkName $_.SourceVNet `
        -Name $_.Name `
        -Force `
        -ErrorAction Stop | Out-Null
}

$remainingPeerings = @(
    @($vnet1Name, $vnet2Name, $vnet3Name) | ForEach-Object {
        Get-AzVirtualNetworkPeering `
            -ResourceGroupName $resourceGroup `
            -VirtualNetworkName $_ `
            -ErrorAction SilentlyContinue
    }
)
$remainingAssociations = @(
    @($vnet2Name, $vnet3Name) | ForEach-Object {
        $virtualNetwork = Get-AzVirtualNetwork -ResourceGroupName $resourceGroup -Name $_
        $subnet = Get-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $virtualNetwork
        if (-not [string]::IsNullOrWhiteSpace($subnet.RouteTable.Id)) {
            $subnet
        }
    }
)
$remainingRouteTables = @(
    Get-AzRouteTable -ResourceGroupName $resourceGroup -Name $routeTable2Name -ErrorAction Stop
    Get-AzRouteTable -ResourceGroupName $resourceGroup -Name $routeTable3Name -ErrorAction Stop
)

Write-Host "Expected final state: peerings 0, associations 0, route tables/routes remain."
Write-Host "Peerings         : $($remainingPeerings.Count)"
Write-Host "Associations     : $($remainingAssociations.Count)"
$remainingRouteTables |
    Select-Object Name, Location, @{ Name = "Routes"; Expression = { @($_.Routes).Count } } |
    Format-Table -AutoSize

if ($remainingPeerings.Count -ne 0 -or $remainingAssociations.Count -ne 0) {
    throw "Reset did not reach the expected final state."
}
