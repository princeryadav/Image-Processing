param location string
param functionAppName string
param storageAccountName string
@secure()
param storageConnectionString string
param blobContainerName string
param tableName string
@secure()
param appInsightsConnectionString string
param environmentName string

// Determine hosting plan SKU based on environment
// Dev: Y1 (Dynamic/Serverless) - lowest cost
// Prod: P1V2 (Premium V2) - higher performance
var hostingPlanSku = environmentName == 'dev' ? 'Y1' : 'P1V2'

// Deploy App Service Plan using AVM
module hostingPlan 'br/public:avm/res/web/serverfarm:0.6.0' = {
  name: 'hostingPlan'
  params: {
    name: '${functionAppName}-plan'
    location: location
    skuName: hostingPlanSku
    skuCapacity: 1
    kind: 'functionapp'
    reserved: false
  }
}

// Deploy Function App using AVM
module functionAppResource 'br/public:avm/res/web/site:0.21.0' = {
  name: 'functionApp'
  params: {
    name: functionAppName
    location: location
    serverFarmResourceId: hostingPlan.outputs.resourceId
    kind: 'functionapp'
    httpsOnly: true
    publicNetworkAccess: 'Enabled'
    managedIdentities: {
      systemAssigned: true
    }
    configs: [
      {
        name: 'appsettings'
        properties: {
          AzureWebJobsStorage: storageConnectionString
          WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: storageConnectionString
          WEBSITE_CONTENTSHARE: toLower(functionAppName)
          FUNCTIONS_EXTENSION_VERSION: '~4'
          FUNCTIONS_WORKER_RUNTIME: 'dotnet-isolated'
          APPLICATIONINSIGHTS_CONNECTION_STRING: appInsightsConnectionString
          ApplicationInsightsAgent_EXTENSION_VERSION: '~3'
          BLOB_CONTAINER_NAME: blobContainerName
          TABLE_NAME: tableName
          STORAGE_ACCOUNT_NAME: storageAccountName
        }
      }
      {
        name: 'web'
        properties: {
          ftpsState: 'Disabled'
          minTlsVersion: '1.2'
        }
      }
    ]
  }
}

// Role assignment for blob storage (Storage Blob Data Contributor)
module blobRoleAssignment 'br/public:avm/res/authorization/role-assignment/rg-scope:0.1.1' = {
  name: 'blobRoleAssignment'
  params: {
    principalId: functionAppResource.outputs.systemAssignedMIPrincipalId!
    roleDefinitionIdOrName: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  }
}

// Role assignment for table storage (Storage Table Data Contributor)
module tableRoleAssignment 'br/public:avm/res/authorization/role-assignment/rg-scope:0.1.1' = {
  name: 'tableRoleAssignment'
  params: {
    principalId: functionAppResource.outputs.systemAssignedMIPrincipalId!
    roleDefinitionIdOrName: '0a9a7e1f-b3f6-4ed5-9b6c-0f02d26c1a8f'
  }
}

output functionAppName string = functionAppResource.outputs.name
output functionAppId string = functionAppResource.outputs.resourceId
output defaultHostName string = functionAppResource.outputs.defaultHostname
output principalId string = functionAppResource.outputs.systemAssignedMIPrincipalId!
