param location string
param existingVnetName string
param subnetName string = 'appServiceIntegrationSubnet'
param existingResourceGroup string
param sqlDbName string
param sqlAdministratorLogin string
param repositoryUrl string
param repositoryBranch string
param containerName string = 'images'
//param linuxFxVersion string

@secure()
param apiKey string

@secure()
param sqlAdministratorLoginPassword string

// storage account
var uniqueName = uniqueString(resourceGroup().id)
var storageAccountSku = 'Standard_LRS'
var storageAccountName = 'stor${uniqueName}'
var appServiceSkuName = 'P1v3'
var appServicePlanName = 'asp-${uniqueName}'
var appServiceCapacity = 1
var sqlServerName = 'sql-${uniqueName}'
var appName = 'drumbeat-${uniqueName}'
var cognitiveServicesAccountName = 'cogsvc${uniqueName}'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-05-01' existing = {
  scope: resourceGroup(existingResourceGroup)
  name: existingVnetName
}

resource appServiceSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-05-01' = {
  name: '${virtualNetwork.name}/${subnetName}'
  properties: {
    addressPrefix: '10.0.1.0/24'
    delegations: [
      {
        name: 'webapp'
        properties: {
          serviceName: 'Microsoft.Web/serverFarms'
        }
      }
    ]
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2020-08-01-preview' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountSku
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
  }
}

resource storageAccountBlobServices 'Microsoft.Storage/storageAccounts/blobServices@2022-05-01' = {
  parent: storageAccount
  name: 'default'
}

resource storageAccountContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  parent: storageAccountBlobServices
  name: containerName
}

// database
resource sqlServer 'Microsoft.Sql/servers@2020-02-02-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdministratorLogin
    administratorLoginPassword: sqlAdministratorLoginPassword
    publicNetworkAccess: 'Enabled'
  }
}

// enable "allow access to Azure services" firewall setting
resource sqlSererFirewallRules 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = {
  parent: sqlServer
  name: 'sql-server-firewall-rules'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource sqlDB 'Microsoft.Sql/servers/databases@2020-02-02-preview' = {
  parent: sqlServer
  name: sqlDbName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
}

// cognitive services
resource cogSvcAccount 'Microsoft.CognitiveServices/accounts@2022-10-01' = {
  name: cognitiveServicesAccountName
  location: location
  sku: {
    name: 'S0'
  }
}

// app service
resource appServicePlan 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: appServicePlanName
  location: location
  /*   properties: {
    reserved: true
  } */
  sku: {
    name: appServiceSkuName
    capacity: appServiceCapacity
  }
}

resource webApp 'Microsoft.Web/sites@2020-06-01' = {
  name: appName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'STORAGE_ACCOUNT_NAME'
          value: storageAccount.name
        }
        {
          name: 'STORAGE_ACCOUNT_KEY'
          value: storageAccount.listKeys().keys[0].value
        }
        {
          name: 'STORAGE_CONTAINER_NAME'
          value: containerName
        }
        {
          name: 'ConnectionStrings:DefaultConnection'
          value: 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDB.name};Persist Security Info=False;User ID=${sqlServer.properties.administratorLogin};Password=${sqlAdministratorLoginPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
        }
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: 'Development'
        }
        {
          name: 'COMPUTER_VISION_SUBSCRIPTION_KEY'
          value: listKeys(cogSvcAccount.id, cogSvcAccount.apiVersion).key1
        }
        {
          name: 'COMPUTER_VISION_ENDPOINT'
          value: cogSvcAccount.properties.endpoint
        }
      ]
    }
  }
}

// deploy app from GitHub source code
resource srcControls 'Microsoft.Web/sites/sourcecontrols@2021-01-01' = {
  name: '${webApp.name}/web'
  properties: {
    repoUrl: repositoryUrl
    branch: repositoryBranch
    isManualIntegration: true
  }
}

output appServiceHostName string = webApp.properties.defaultHostName
