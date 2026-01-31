param location string
param storageAccountName string
param storageSku string
param blobContainerName string
param tableName string

// Deploy Storage Account using AVM
module storageAccount 'br/public:avm/res/storage/storage-account:0.31.0' = {
  name: 'storageAccount'
  params: {
    name: storageAccountName
    location: location
    kind: 'StorageV2'
    skuName: storageSku
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Enabled'
    blobServices: {
      containers: [
        {
          name: blobContainerName
          publicAccess: 'None'
        }
      ]
      deleteRetentionPolicyEnabled: true
      deleteRetentionPolicyDays: 7
    }
    tableServices: {
      tables: [
        {
          name: tableName
        }
      ]
    }
  }
}

output storageAccountName string = storageAccount.outputs.name
output storageAccountId string = storageAccount.outputs.resourceId
@secure()
output storageConnectionString string = storageAccount.outputs.primaryConnectionString
