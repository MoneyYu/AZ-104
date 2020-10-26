## Login
Connect-AzAccount
# Connect-AzAccount -Environment AzureChinaCloud

## Set the subscriptions
Set-AzContext -SubscriptionId "xxxx-xxxx-xxxx-xxxx"

$ResourceGroupName = "Demo10433"

## Create the resource group
New-AzResourceGroup -Name $ResourceGroupName -Location southeastasia

New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile  azuredeploy.json -TemplateParameterFile azuredeploy.parameters.json
