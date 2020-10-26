$resourceGroup = "Demo104"
$location = "southeastasia"
$name = "contoso.xyz"

## 列出區域中的 DNS 記錄
Get-AzDnsRecordSet -ZoneName $name -ResourceGroupName $resourceGroup

## 取得您區域中的名稱伺服器清單
Get-AzDnsRecordSet -ZoneName $name -ResourceGroupName $resourceGroup -RecordType ns