source ./.env

resourceGroupName='drumbeat-rg'
location='australiaeast'
bicepFilePath='../infra/deploy.bicep'
parameterFilePath='../infra/deploy.parameters.json'

az group create -n $resourceGroupName -l $location

az deployment group create -n 'infra-deployment' \
    --resource-group $resourceGroupName \
    --mode Incremental \
    --template-file $bicepFilePath \
    --parameters $parameterFilePath \
    --parameters sqlAdministratorLoginPassword=$sqlAdministratorLoginPassword \
    --parameters linuxFxVersion='DOTNETCORE|6.0'
