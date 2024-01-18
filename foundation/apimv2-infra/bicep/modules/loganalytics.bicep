@description('Name of the Log Analytics Workspace to be created.')
param logAnalyticsWorkspaceName string

@description('Location for the resource.')
param location string

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'pergb2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// This outputs the Workspace ID of the Log Analytics Workspace we just created. This is different from the Resource ID.
// This output is used in the creation of our Application Insights instance.

output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
