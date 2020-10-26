$resourceGroup = "Demo104"
$location = "southeastasia"
$name = "demo1027"

$virtualNetwork = New-AzVirtualNetwork `
  -ResourceGroupName $resourceGroup `
  -Location $location `
  -Name $name `
  -AddressPrefix 10.10.0.0/16