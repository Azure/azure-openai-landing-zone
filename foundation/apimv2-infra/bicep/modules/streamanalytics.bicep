@description('Name of the Azure Stream Analytics to be created.')
param streamAnalyticsName string

@description('Location for the resource.')
param location string

resource streamAnalytics 'Microsoft.StreamAnalytics/streamingjobs@2021-10-01-preview' = {
  name: streamAnalyticsName
  location: location
  sku: {
    name: 'StandardV2'
    capacity: 3
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'StandardV2'
    }
    eventsOutOfOrderPolicy: 'Adjust'
    outputErrorPolicy: 'Stop'
    eventsOutOfOrderMaxDelayInSeconds: 0
    eventsLateArrivalMaxDelayInSeconds: 5
    dataLocale: 'en-US'
    compatibilityLevel: '1.2'
    contentStoragePolicy: 'SystemAccount'
    jobType: 'Cloud'
  }
}
