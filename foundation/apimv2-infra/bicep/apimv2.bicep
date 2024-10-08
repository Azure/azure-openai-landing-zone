//****************************************************************************************
// General documentation
//****************************************************************************************

// This is a Bicep template. Bicep is a Domain Specific Language (DSL) that is used to deploy Azure resources.
// Bicep is a declarative language, meaning that you declare the desired state of the resources you want to deploy.
// Bicep is a transpiler, meaning that it takes the Bicep code and transpiles it into ARM JSON. This ARM JSON is then used to deploy the resources.

// In this template we're making heavy use of modules. For more information on modules refer to: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/modules

// To learn how to deploy Bicep templates please refer to this documentation:
// https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-vscode
// https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-cli
// https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-powershell
// https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-cloud-shell

//****************************************************************************************
// Parameters
//****************************************************************************************

param prefix string

param location string

@description('Specifies all secrets wrapped in a secure object.')
@secure()
param secretsObject object

//****************************************************************************************
// Variables
//****************************************************************************************

// Variables related to setting naming conventions for resources
// Below are examples of string concatenation in Bicep. Refer to: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-functions-string#concat
// Worth mentioning is that Storage Accounts have unique naming standards compared to other resources: https://learn.microsoft.com/en-us/azure/storage/common/storage-account-overview#storage-account-name
// All abbreviations used in the naming conventions are defined here: https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations
var resourceGroupName = '${prefix}-rg'
var apiManagementName = '${prefix}-apim'
var keyVaultName = '${prefix}-kv'
var eventHubNamespaceName = '${prefix}-evhns'
var eventHubName = '${prefix}-evh'
var logAnalyticsWorkspaceName = '${prefix}-log'
var applicationInsightsName = '${prefix}-appi'
var storageAccountName = '${prefix}st'
var streamAnalyticsName = '${prefix}-asa'

//****************************************************************************************
// Resources
//****************************************************************************************

// This is the root of the overall deployment. We must first create the Resource Group.
// Resource Groups exist directly below the Subscription level. Therefore, we must specify the scope of the deployment to be the Subscription.
// You can learn more about setting scope here: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-to-subscription#set-scope
// For all subsequent resources we will set the scope to be the Resource Group we're creating here.
targetScope = 'subscription'
resource deployResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  properties: {}
}

module deployAPIM './modules/apimService.bicep' = {
  name: 'APIM'
  scope: deployResourceGroup
  params: {
    apiManagementName: apiManagementName
    location: location
  }
  dependsOn: [
    deployApplicationInsights
    deployEventHub
    deployKeyVault
  ]
}

module deployAPIMConfiguration './modules/apimServiceConfiguration.bicep' = {
  name: 'APIMConfiguration'
  scope: deployResourceGroup
  params: {
    apiManagementName: apiManagementName
    applicationInsightsName: applicationInsightsName
    eventHubNamespaceName: eventHubNamespaceName
    eventHubName: eventHubName
    keyVaultName: keyVaultName
    secretsObject: secretsObject
  }
  dependsOn: [
    deployAPIM
    deployKeyVault
    deployRoleAssignments
  ]
}

module deployKeyVault './modules/keyvault.bicep' = {
  name: 'KeyVault'
  scope: deployResourceGroup
  params: {
    keyVaultName: keyVaultName
    location: location
    secretsObject: secretsObject
  }
}

module deployEventHub './modules/eventhub.bicep' = {
  name: 'EventHub'
  scope: deployResourceGroup
  params: {
    eventHubNamespaceName: eventHubNamespaceName
    eventHubName: eventHubName
    location: location
  }
  dependsOn: [
    deployKeyVault
  ]
}

module deployLogAnalyticsWorkspace './modules/loganalytics.bicep' = {
  name: 'LogAnalyticsWorkspace'
  scope: deployResourceGroup
  params: {
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    location: location
  }
  dependsOn: [
    deployKeyVault
  ]
}

module deployApplicationInsights './modules/appinsights.bicep' = {
  name: 'ApplicationInsights'
  scope: deployResourceGroup
  params: {
    applicationInsightsName: applicationInsightsName
    location: location
    workspaceResourceId: deployLogAnalyticsWorkspace.outputs.logAnalyticsWorkspaceId
  }
  dependsOn: [
    deployLogAnalyticsWorkspace
    deployKeyVault
  ]
}

module deployStorageAccount './modules/storageaccount.bicep' = {
  name: 'StorageAccount'
  scope: deployResourceGroup
  params: {
    storageAccountName: storageAccountName
    location: location
  }
  dependsOn: [
    deployKeyVault
  ]
}

module deployStreamAnalytics './modules/streamanalytics.bicep' = {
  name: 'StreamAnalytics'
  scope: deployResourceGroup
  params: {
    streamAnalyticsName: streamAnalyticsName
    location: location
  }
  dependsOn: [
    deployEventHub
    deployStorageAccount
    deployKeyVault
  ]
}

module deployRoleAssignments './modules/roleAssignment.bicep' = {
  name: 'roleAssignments'
  scope: deployResourceGroup
  params: {
    APIMPrincipalId: deployAPIM.outputs.managedIdentityPrincipalID
    keyVaultName: keyVaultName
  }
  dependsOn: [
    deployAPIM
    deployKeyVault
  ]
}
