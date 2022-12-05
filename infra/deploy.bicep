param location string
param subnetName string = 'appServiceIntegrationSubnet'
param sqlDbName string
param sqlAdministratorLogin string
param repositoryUrl string
param repositoryBranch string
param containerName string = 'images'
param linuxApp bool = true
param linuxFxVersion string
param adminUserObjectId string

@secure()
param sqlAdministratorLoginPassword string

// storage account
var uniqueName = uniqueString(resourceGroup().id)
var storageAccountSku = 'Standard_LRS'
var storageAccountName = 'stor${uniqueName}'
var appServiceSkuName = 'P1v3'
var linuxAppServicePlanName = 'linux-asp-${uniqueName}'
var windowsAppServicePlanName = 'windows-asp-${uniqueName}'
var appServiceCapacity = 1
var sqlServerName = 'sql-${uniqueName}'
var appName = 'drumbeat-ai-${uniqueName}'
var cognitiveServicesAccountName = 'cogsvc${uniqueName}'
var keyVaultName = 'kv${uniqueName}'
var vnetName = 'vnet-${uniqueName}'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
          serviceEndpoints: [
            {
              locations: [
                location
              ]
              service: 'Microsoft.KeyVault'
            }
            {
              locations: [
                location
              ]
              service: 'Microsoft.Sql'
            }
          ]
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

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: [
      {
        objectId: adminUserObjectId
        permissions: {
          secrets: [
            'all'
          ]
          certificates: [
            'all'
          ]
          keys: [
            'all'
          ]
        }
        tenantId: tenant().tenantId
      }
    ]
    tenantId: tenant().tenantId
    enableRbacAuthorization: false
    enableSoftDelete: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      virtualNetworkRules: [
        {
          id: virtualNetwork.properties.subnets[0].id
        }
      ]
    }
  }
}

resource storageAccountKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'storageAccountKey'
  properties: {
    value: storageAccount.listKeys().keys[0].value
  }
}

resource cognitiveServicesKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'cognitiveServicesKey'
  properties: {
    value: listKeys(cogSvcAccount.id, cogSvcAccount.apiVersion).key1
  }
}

resource sqlServerConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'sqlServerConnectionString'
  properties: {
    value: 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDB.name};Persist Security Info=False;User ID=${sqlServer.properties.administratorLogin};Password=${sqlAdministratorLoginPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
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

resource sqlServerVnetRules 'Microsoft.Sql/servers/virtualNetworkRules@2022-05-01-preview' = {
  name: 'sql-server-vnet-rule-01'
  parent: sqlServer
  properties: {
    virtualNetworkSubnetId: virtualNetwork.properties.subnets[0].id
  }
}

// enable "allow access to Azure services" firewall setting
resource sqlServerFirewallRules 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = {
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
  kind: 'CognitiveServices'
  sku: {
    name: 'S0'
  }
  properties: {
    restrictOutboundNetworkAccess: false

  }
}

// app service
resource linuxAppServicePlan 'Microsoft.Web/serverfarms@2020-06-01' = if (linuxApp) {
  name: linuxAppServicePlanName
  location: location
  kind: 'linux'
  properties: {
    reserved: true
  }
  sku: {
    name: appServiceSkuName
    capacity: appServiceCapacity
  }
}

// app service
resource windowsAppServicePlan 'Microsoft.Web/serverfarms@2020-06-01' = if (!linuxApp) {
  name: windowsAppServicePlanName
  location: location
  sku: {
    name: appServiceSkuName
    capacity: appServiceCapacity
  }
}

module webAppModule 'modules/webapp.bicep' = {
  name: 'web-app-module'
  params: {
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorLoginPassword: sqlAdministratorLoginPassword
    subnetId: virtualNetwork.properties.subnets[0].id
    keyVaultName: keyVault.name
    sqlDbName: sqlDbName
    sqlServerFullyQualifiedDomainName: sqlServer.properties.fullyQualifiedDomainName
    repositoryBranch: repositoryBranch
    repositoryUrl: repositoryUrl
    linuxApp: true
    appName: appName
    appServicePlanId: linuxApp ? linuxAppServicePlan.id : windowsAppServicePlan.id
    cognitiveServicesKeySecretSecretUri: cognitiveServicesKeySecret.properties.secretUri
    cogSvcAccountEndpoint: cogSvcAccount.properties.endpoint
    containerName: containerName
    linuxFxVersion: linuxFxVersion
    location: location
    storageAccountKeySecretUri: storageAccountKeySecret.properties.secretUri
    storageAccountName: storageAccount.name
  }
}

output appServiceHostName string = webAppModule.outputs.defaultHostName
