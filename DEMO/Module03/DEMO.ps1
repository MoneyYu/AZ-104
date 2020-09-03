## Install the Azure PowerShell
if ($PSVersionTable.PSEdition -eq 'Desktop' -and (Get-Module -Name AzureRM -ListAvailable)) {
    Write-Warning -Message ('Az module not installed. Having both the AzureRM and ' +
      'Az modules installed at the same time is not supported.')
} else {
    Install-Module -Name Az -AllowClobber -Scope CurrentUser
}

## Update the Azure PowerShell
if ($PSVersionTable.PSEdition -eq 'Desktop' -and (Get-Module -Name AzureRM -ListAvailable)) {
    Write-Warning -Message ('Az module not installed. Having both the AzureRM and ' +
      'Az modules installed at the same time is not supported.')
} else {
    Install-Module -Name Az -AllowClobber -Force
}

## List the avalible command of Az.Compute
Get-Command -Verb Get -Noun AzVM* -Module Az.Compute

## Login
Connect-AzAccount
# Connect-AzAccount -Environment AzureChinaCloud

## List the subscriptions
Get-AzSubscription

## Set the subscriptions
Set-AzContext -SubscriptionId "xxxx-xxxx-xxxx-xxxx"

## Create the resource group
New-AzResourceGroup -Name demopsgroup -Location southeastasia

$cred = Get-Credential -Message "Enter a username and password for the virtual machine."

$vmParams = @{
    ResourceGroupName = 'demopsgroup'
    Name = 'demopsgroupvm1'
    Location = 'southeastasia'
    ImageName = 'Win2016Datacenter'
    PublicIpAddressName = 'demopsgroupvm1PublicIp'
    Credential = $cred
    OpenPorts = 3389
  }

$newVM1 = New-AzVM @vmParams

$newVM1