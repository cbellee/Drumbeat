param location string
param appName string
param appServicePlanId string
param linuxFxVersion string
param sqlServerFullyQualifiedDomainName string
param sqlDbName string
param sqlAdministratorLogin string

@secure()
param sqlAdministratorLoginPassword string

param subnetId string
param storageAccountName string
param storageAccountKeySecretUri string
param cognitiveServicesKeySecretSecretUri string
param containerName string
param cogSvcAccountEndpoint string
param repositoryUrl string
param repositoryBranch string
param linuxApp bool = true
param keyVaultName string

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2022-07-01' = {
  name: 'add'
  parent: keyVault
  properties: {
    accessPolicies: [
      {
        objectId: webApp.identity.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
        tenantId: tenant().tenantId
      }
    ]
  }
}

resource webApp 'Microsoft.Web/sites@2022-03-01' = {
  name: appName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    siteConfig: {
      linuxFxVersion: (linuxFxVersion != null) ? linuxFxVersion : null
      connectionStrings: [
        {
          name: 'DefaultConnection'
          connectionString: 'Server=tcp:${sqlServerFullyQualifiedDomainName},1433;Initial Catalog=${sqlDbName};Persist Security Info=False;User ID=${sqlAdministratorLogin};Password=${sqlAdministratorLoginPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;' // '@Microsoft.KeyVault(SecretUri=${sqlServerConnectionStringSecret}' 
          type: 'SQLAzure'
        }
      ]
      appSettings: [
        {
          name: 'STORAGE_ACCOUNT_NAME'
          value: storageAccountName
        }
        {
          name: 'STORAGE_ACCOUNT_KEY'
          value: '@Microsoft.KeyVault(SecretUri=${storageAccountKeySecretUri})'
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
          value: '@Microsoft.KeyVault(SecretUri=${cognitiveServicesKeySecretSecretUri})'
        }
        {
          name: 'COMPUTER_VISION_ENDPOINT'
          value: cogSvcAccountEndpoint
        }
        {
          name: 'WEBSITE_WEBDEPLOY_USE_SCM'
          value: 'true'
        }
      ]
    }
  }
}

resource vnetIntegration 'Microsoft.Web/sites/networkConfig@2022-03-01' = {
  name: 'virtualNetwork'
  parent: webApp
  properties: {
   subnetResourceId: subnetId
   swiftSupported: true
  }
}

resource logging 'Microsoft.Web/sites/config@2022-03-01' = {
  name: 'logs'
  kind: 'string'
  parent: webApp
  properties: {
    applicationLogs: {
      fileSystem: {
        level: 'Verbose'
      }
    }
    detailedErrorMessages: {
      enabled: true
    }
    failedRequestsTracing: {
      enabled: true
    }
    httpLogs: {
      fileSystem: {
        enabled: true
        retentionInDays: 7
        retentionInMb: 100
      }
    }
  }
}

// deploy app from GitHub source code
resource srcControls 'Microsoft.Web/sites/sourcecontrols@2021-01-01' = {
  name: '${webApp.name}/web'
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
      isLinux: linuxApp
      generateWorkflowFile: false
    }
  }
}

output name string = webApp.name
output defaultHostName string = webApp.properties.defaultHostName
output principalId string = webApp.identity.principalId
