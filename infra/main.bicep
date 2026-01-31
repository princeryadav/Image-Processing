targetScope = 'resourceGroup'

param location string = resourceGroup().location
param namePrefix string = 'imgproc'
param environmentName string = 'dev'

// Storage SKU: Standard_LRS for dev, Standard_GRS for prod
var storageSku = environmentName == 'dev' ? 'Standard_LRS' : 'Standard_GRS'

// Log Analytics pricing tier: PerGB2018 for dev, CapacityReservation100GB for prod
var logAnalyticsSku = environmentName == 'dev' ? 'PerGB2018' : 'CapacityReservation100GB'

// Log Analytics retention: 7 days for dev, 30 days for prod
var logAnalyticsRetention = environmentName == 'dev' ? 7 : 30

// App Insights retention: 7 days for dev, 30 days for prod
var appInsightsRetention = environmentName == 'dev' ? 7 : 30

var storageAccountName = toLower(substring('${namePrefix}${environmentName}${uniqueString(resourceGroup().id)}', 0, 24))
var functionAppName = toLower('${namePrefix}-${environmentName}-func')
var appInsightsName = toLower('${namePrefix}-${environmentName}-ai')
var logAnalyticsName = toLower('${namePrefix}-${environmentName}-law')
var blobContainerName = 'images'
var tableName = 'ImageMetadata'

module storage 'modules/storage.bicep' = {
  params: {
    location: location
    storageAccountName: storageAccountName
    storageSku: storageSku
    blobContainerName: blobContainerName
    tableName: tableName
  }
}

module appInsights 'modules/appinsights.bicep' = {
  params: {
    location: location
    appInsightsName: appInsightsName
    logAnalyticsName: logAnalyticsName
    logAnalyticsSku: logAnalyticsSku
    logAnalyticsRetention: logAnalyticsRetention
    appInsightsRetention: appInsightsRetention
  }
}

module functionApp 'modules/functionapp.bicep' = {
  params: {
    location: location
    functionAppName: functionAppName
    storageAccountName: storage.outputs.storageAccountName
    storageConnectionString: storage.outputs.storageConnectionString
    blobContainerName: blobContainerName
    tableName: tableName
    appInsightsConnectionString: appInsights.outputs.connectionString
    environmentName: environmentName
  }
}

output storageAccountName string = storage.outputs.storageAccountName
output blobContainerName string = blobContainerName
output tableName string = tableName
output functionAppName string = functionApp.outputs.functionAppName
output appInsightsInstrumentationKey string = appInsights.outputs.instrumentationKey
output functionAppUrl string = 'https://${functionApp.outputs.defaultHostName}'
