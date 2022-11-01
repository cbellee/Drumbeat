param location string
param appName string
param appServicePlanId string
param linuxFxVersion string
param sqlServerConnectionStringSecret string
param storageAccountName string
param storageAccountKeySecretUri string
param cognitiveServicesKeySecretSecretUri string
param containerName string
param cogSvcAccountEndpoint string
param repositoryUrl string
param repositoryBranch string
param linuxApp bool = true

resource webApp 'Microsoft.Web/sites@2020-06-01' = {
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
          connectionString: '@Microsoft.KeyVault(SecretUri=${sqlServerConnectionStringSecret}' //'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDB.name};Persist Security Info=False;User ID=${sqlServer.properties.administratorLogin};Password=${sqlAdministratorLoginPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
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
          value: '@Microsoft.KeyVault(SecretUri=${storageAccountKeySecretUri}' //storageAccount.listKeys().keys[0].value
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
          value: '@Microsoft.KeyVault(SecretUri=${cognitiveServicesKeySecretSecretUri}' //listKeys(cogSvcAccount.id, cogSvcAccount.apiVersion).key1
        }
        {
          name: 'COMPUTER_VISION_ENDPOINT'
          value: cogSvcAccountEndpoint
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
    isManualIntegration: false
    isGitHubAction: true
    gitHubActionConfiguration: {
      codeConfiguration: {
        runtimeStack: 'dotnetcore'
        runtimeVersion: '6.0'
      }
      isLinux: linuxApp ? true : false
      generateWorkflowFile: false
    }
  }
}

output name string = webApp.name
output defaultHostName string = webApp.properties.defaultHostName
output principalId string = webApp.identity.principalId
