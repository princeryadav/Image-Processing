param location string
param appInsightsName string
param logAnalyticsName string
param logAnalyticsSku string = 'PerGB2018'
param logAnalyticsRetention int = 30
param appInsightsRetention int = 30

// Deploy Log Analytics Workspace using AVM
module workspace 'br/public:avm/res/operational-insights/workspace:0.15.0' = {
  name: 'workspace'
  params: {
    name: logAnalyticsName
    location: location
    skuName: logAnalyticsSku
    dataRetention: logAnalyticsRetention
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Deploy Application Insights using AVM
module appInsights 'br/public:avm/res/insights/component:0.7.1' = {
  name: 'appInsights'
  params: {
    name: appInsightsName
    location: location
    applicationType: 'web'
    kind: 'web'
    retentionInDays: appInsightsRetention
    workspaceResourceId: workspace.outputs.resourceId
  }
}

output instrumentationKey string = appInsights.outputs.instrumentationKey
output connectionString string = appInsights.outputs.connectionString
output resourceId string = appInsights.outputs.resourceId
