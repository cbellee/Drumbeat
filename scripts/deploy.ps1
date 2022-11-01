param(
    [string]$resourceGroupName = 'drumbeat-rg',
    [string]$location = 'australiaeast',
    [string]$bicepFilePath = '../infra/deploy.bicep',
    [string]$parameterFilePath = '../infra/deploy.parameters.json',
    [securestring]$sqlAdministratorLoginPassword,
    [securestring]$apiKey
)

New-AzResourceGroup -Name $resourceGroupName -Location $location -Force

New-AzResourceGroupDeployment -Name 'infra-deployment' `
    -ResourceGroupName $resourceGroupName `
    -Mode Incremental `
    -TemplateFile $bicepFilePath `
    -TemplateParameterFile $parameterFilePath `
    -sqlAdministratorLoginPassword $sqlAdministratorLoginPassword `
    -linuxFxVersion 'DOTNETCORE|6.0'
