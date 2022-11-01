param location string
param existingVnetName string
param subnetName string = 'appServiceIntegrationSubnet'
param existingResourceGroup string
param sqlDbName string
param sqlAdministratorLogin string
param repositoryUrl string
param repositoryBranch string
param containerName string = 'images'
param linuxApp bool = true
param linuxFxVersion string

@description('Specifies the role the user will get with the secret in the vault. Valid values are: Key Vault Administrator, Key Vault Certificates Officer, Key Vault Crypto Officer, Key Vault Crypto Service Encryption User, Key Vault Crypto User, Key Vault Reader, Key Vault Secrets Officer, Key Vault Secrets User.')
@allowed([
  'Key Vault Administrator'
  'Key Vault Certificates Officer'
  'Key Vault Crypto Officer'
  'Key Vault Crypto Service Encryption User'
  'Key Vault Crypto User'
  'Key Vault Reader'
  'Key Vault Secrets Officer'
  'Key Vault Secrets User'
])
param roleName string = 'Key Vault Secrets User'

var roleIdMapping = {
  'Key Vault Administrator': '00482a5a-887f-4fb3-b363-3b7fe8e74483'
  'Key Vault Certificates Officer': 'a4417e6f-fecd-4de8-b567-7b0420556985'
  'Key Vault Crypto Officer': '14b46e9e-c2b7-41b4-b07b-48a6ebf60603'
  'Key Vault Crypto Service Encryption User': 'e147488a-f6f5-4113-8e2d-b22465e65bf6'
  'Key Vault Crypto User': '12338af0-0e69-4776-bea7-57ae8d297424'
  'Key Vault Reader': '21090545-7ca7-4776-b22c-e363652d74d2'
  'Key Vault Secrets Officer': 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
  'Key Vault Secrets User': '4633458b-17de-408a-b874-0445c86b69e6'
}

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
var appName = 'drumbeat-${uniqueName}'
var cognitiveServicesAccountName = 'cogsvc${uniqueName}'
var keyVaultName = 'kv${uniqueName}'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  scope: resourceGroup(existingResourceGroup)
  name: existingVnetName
}

resource appServiceSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-05-01' = {
  name: '${virtualNetwork.name}/${subnetName}'
  properties: {
    addressPrefix: '10.0.1.0/24'
    serviceEndpoints: [
      {
        locations: [
          location
        ]
        service: 'Microsoft.KeyVault'
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
    tenantId: tenant().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      virtualNetworkRules: [
        {
          id: appServiceSubnet.id
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

module kvRoleAssignment 'modules/roleAssignment.bicep' = {
  name: 'keyVault-role-assignment-module'
  params: {
    keyVaultId: keyVault.id
    keyVaultName: keyVault.name
    principalId: webAppModule.outputs.principalId
    roleName: roleIdMapping[roleName]
  }
}

/* resource kvRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(roleIdMapping[roleName], webAppModule.outputs.principalId, keyVault.id)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIdMapping[roleName])
    principalId: webAppModule.outputs.principalId
    principalType: 'ServicePrincipal'
  }
} */

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
    repositoryBranch: repositoryBranch
    repositoryUrl: repositoryUrl
    linuxApp: true
    appName: appName
    appServicePlanId: linuxApp ? linuxAppServicePlan.id : windowsAppServicePlan.id
    cognitiveServicesKeySecretSecretUri: '@Microsoft.KeyVault(SecretUri=${cognitiveServicesKeySecret.properties.secretUri}'
    cogSvcAccountEndpoint: cogSvcAccount.properties.endpoint
    containerName: containerName
    linuxFxVersion: linuxFxVersion
    location: location
    sqlServerConnectionStringSecret: '@Microsoft.KeyVault(SecretUri=${sqlServerConnectionStringSecret}'
    storageAccountKeySecretUri: '@Microsoft.KeyVault(SecretUri=${storageAccountKeySecret.properties.secretUri}'
    storageAccountName: storageAccount.name
  }
}

/* resource webApp 'Microsoft.Web/sites@2020-06-01' = {
  name: appName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: linuxApp ? linuxAppServicePlan.id : windowsAppServicePlan.id
    siteConfig: {
      linuxFxVersion: (linuxFxVersion != null) ? linuxFxVersion : null
      connectionStrings: [
        {
          name: 'DefaultConnection'
          connectionString: '@Microsoft.KeyVault(SecretUri=${sqlServerConnectionStringSecret}' //'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDB.name};Persist Security Info=False;User ID=${sqlServer.properties.administratorLogin};Password=${sqlAdministratorLoginPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
          type: 'SQLAzure'
        }
      ]
      appSettings: [
        {
          name: 'STORAGE_ACCOUNT_NAME'
          value: storageAccount.name
        }
        {
          name: 'STORAGE_ACCOUNT_KEY'
          value: '@Microsoft.KeyVault(SecretUri=${storageAccountKeySecret.properties.secretUri}' //storageAccount.listKeys().keys[0].value
        }
        {
          name: 'STORAGE_CONTAINER_NAME'
          value: containerName
        }
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: 'Development'
        }
        {
          name: 'COMPUTER_VISION_SUBSCRIPTION_KEY'
          value: '@Microsoft.KeyVault(SecretUri=${cognitiveServicesKeySecret.properties.secretUri}' //listKeys(cogSvcAccount.id, cogSvcAccount.apiVersion).key1
        }
        {
          name: 'COMPUTER_VISION_ENDPOINT'
          value: cogSvcAccount.properties.endpoint
        }
      ]
    }
  }
} */

// deploy app from GitHub source code
/* resource srcControls 'Microsoft.Web/sites/sourcecontrols@2021-01-01' = {
  name: '${webAppModule.outputs.name}/web'
  properties: {
    repoUrl: repositoryUrl
    branch: repositoryBranch
    isManualIntegration: false
    isGitHubAction: true
    gitHubActionConfiguration: {
      codeConfiguration: {
        runtimeStack: 'dotnetcore'
        runtimeVersion: '6.0'
      }
      isLinux: linuxApp ? true : false
      generateWorkflowFile: true
    }
  }
} */

output appServiceHostName string = webAppModule.outputs.defaultHostName
