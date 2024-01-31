//****************************************************************************************
// Parameters
//****************************************************************************************

@description('Name of the API Management instance. Must be globally unique.')
param apiManagementName string

param applicationInsightsName string

param eventHubNamespaceName string

param eventHubName string

param keyVaultName string

@secure()
param secretsObject object

param APIPolicies object

//****************************************************************************************
// Variables
//****************************************************************************************

var openAIOpenAPISpec = loadTextContent('../artifacts/apim_v2_openai_2023_12_01_preview_inference_spec.openapi+json.json')


//****************************************************************************************
// Existing resource references
//****************************************************************************************

resource existingApiManagement 'Microsoft.ApiManagement/service@2023-03-01-preview' existing = {
  name: apiManagementName
}

resource existingApplicationInsights 'microsoft.insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

resource existingEventHubAuthRule 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2022-10-01-preview' existing = {
  name: '${eventHubNamespaceName}/${eventHubName}/apimLoggerAccessPolicy'
}

//****************************************************************************************
// APIs
//****************************************************************************************

resource apiManagementAPI 'Microsoft.ApiManagement/service/apis@2023-03-01-preview' = [for API in items(APIPolicies): {
  parent: existingApiManagement
  name: API.value.name
  properties: {
    displayName: API.value.name
    format: 'openapi+json'
    value: openAIOpenAPISpec
    subscriptionRequired: true
    type: 'http'
    protocols: [
      'https'
    ]
    serviceUrl: existingApiManagement.properties.gatewayUrl
    path: 'openai/deployments/${API.value.name}'
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'subscription-key'
    }
  }
}]

//********************************************
// Policies
//********************************************

resource apiManagementAPIPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-03-01-preview' = [for API in items(APIPolicies): {
  name: '${apiManagementName}/${API.value.name}/policy'
  dependsOn: [
    apiManagementAPI
    namedValuesEndpoints
    namedValuesKeys
  ]
  properties: {
    value: API.value.policyPath
    format: 'rawxml'
  }
}]

//********************************************
// Product
//********************************************

resource apiManagementProduct 'Microsoft.ApiManagement/service/products@2023-03-01-preview' = {
  parent: existingApiManagement
  name: 'openai'
  dependsOn: [apiManagementAPI]
  properties: {
    displayName: 'OpenAI'
    description: 'Echo for Azure OpenAI API Calls'
    subscriptionRequired: true
    approvalRequired: false
    state: 'published'
  }
}

resource apiManagementProductAPI 'Microsoft.ApiManagement/service/products/apis@2023-03-01-preview' = [for API in items(APIPolicies): {
  parent: apiManagementProduct
  name: API.value.name
}]

resource apiManagementProductGroup 'Microsoft.ApiManagement/service/products/groups@2023-03-01-preview' = {
  parent: apiManagementProduct
  name: 'administrators'
}

resource apiManagementProductDevSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-03-01-preview' = {
  parent: existingApiManagement
  name: 'aoai-dev-subscription'
  properties: {
    scope: apiManagementProduct.id
    displayName: 'AOAI Development Subscription'
    state: 'active'
    allowTracing: false
  }
}

resource apiManagementProductProdSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-03-01-preview' = {
  parent: existingApiManagement
  name: 'aoai-prod-subscription'
  properties: {
    scope: apiManagementProduct.id
    displayName: 'AOAI Production Subscription'
    state: 'active'
    allowTracing: false
  }
}

//********************************************
// Named Values 
//********************************************

resource namedValuesEndpoints 'Microsoft.ApiManagement/service/namedValues@2023-03-01-preview' = [for endpoint in items(secretsObject): {
  parent: existingApiManagement
  name: endpoint.value.endpointName
  properties: {
    displayName: endpoint.value.endpointName
    value: endpoint.value.endpointURL
    secret: false
  }
}]

resource namedValuesKeys 'Microsoft.ApiManagement/service/namedValues@2023-03-01-preview' = [for endpoint in items(secretsObject): {
  parent: existingApiManagement
  name: endpoint.value.secretName
  properties: {
    displayName: endpoint.value.secretName
    keyVault: {
      secretIdentifier: 'https://${keyVaultName}.vault.azure.net/secrets/${endpoint.value.secretName}'
    }
    tags: []
    secret: true
  }
}]

//********************************************
// Logging related resources
//********************************************
//**********************
// Loggers https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-app-insights?tabs=bicep
//**********************

resource appInsightsLogger 'Microsoft.ApiManagement/service/loggers@2023-05-01-preview' = {
  name: 'appinsights-logger'
  parent: existingApiManagement
  properties: {
    loggerType: 'applicationInsights'
    credentials: {
      instrumentationKey: existingApplicationInsights.properties.InstrumentationKey
    }
    isBuffered: true
    resourceId: existingApplicationInsights.id
  }
}

resource eventHubLogger 'Microsoft.ApiManagement/service/loggers@2023-05-01-preview' = {
  name: 'eventhub-logger'
  parent: existingApiManagement
  properties: {
    loggerType: 'azureEventHub'
    credentials: {
      name: 'apimLoggerAccessPolicy'
      connectionString: existingEventHubAuthRule.listKeys().primaryConnectionString
    }
    isBuffered: true
  }
}

resource azureMonitorLogger 'Microsoft.ApiManagement/service/loggers@2023-05-01-preview' = {
  name: 'azuremonitor'
  parent: existingApiManagement
  properties: {
    loggerType: 'azureMonitor'
    isBuffered: true
  }
}

//**********************
// Diagnostics, these associate the service or API to the Logger
//**********************

resource serviceAppInsightsDiagnostic 'Microsoft.ApiManagement/service/diagnostics@2023-03-01-preview' = {
  parent: existingApiManagement
  name: 'applicationinsights'
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'Legacy'
    logClientIp: true
    loggerId: appInsightsLogger.id
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: {
        dataMasking: {
          queryParams: [
            {
              value: '*'
              mode: 'Hide'
            }
          ]
        }
      }
    }
    backend: {
      request: {
        dataMasking: {
          queryParams: [
            {
              value: '*'
              mode: 'Hide'
            }
          ]
        }
      }
    }
  }
}

resource serviceAzureMonitorDiagnostic 'Microsoft.ApiManagement/service/diagnostics@2023-03-01-preview' = {
  parent: existingApiManagement
  name: 'azuremonitor'
  properties: {
    logClientIp: true
    loggerId: azureMonitorLogger.id
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: {
        dataMasking: {
          queryParams: [
            {
              value: '*'
              mode: 'Hide'
            }
          ]
        }
      }
    }
    backend: {
      request: {
        dataMasking: {
          queryParams: [
            {
              value: '*'
              mode: 'Hide'
            }
          ]
        }
      }
    }
  }
}

resource serviceAPIAppInsightsDiagnostic 'Microsoft.ApiManagement/service/apis/diagnostics@2023-03-01-preview' = [for API in items(APIPolicies):{
  name: '${apiManagementName}/${API.value.name}/applicationinsights'
  dependsOn: [apiManagementAPI]
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'Legacy'
    verbosity: 'verbose'
    logClientIp: true
    loggerId: appInsightsLogger.id
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: {
        headers: []
        body: {
          bytes: 8192
        }
      }
      response: {
        headers: []
        body: {
          bytes: 8192
        }
      }
    }
    backend: {
      request: {
        headers: []
        body: {
          bytes: 8192
        }
      }
      response: {
        headers: []
        body: {
          bytes: 8192
        }
      }
    }
    metrics: true
  }
}]

resource serviceAPIAzureMonitorDiagnostic 'Microsoft.ApiManagement/service/apis/diagnostics@2023-03-01-preview' = [for API in items(APIPolicies):{
  name: '${apiManagementName}/${API.value.name}/azuremonitor'
  dependsOn: [apiManagementAPI]
  properties: {
    alwaysLog: 'allErrors'
    verbosity: 'verbose'
    logClientIp: true
    loggerId: azureMonitorLogger.id
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: {
        headers: []
        body: {
          bytes: 8192
        }
      }
      response: {
        headers: []
        body: {
          bytes: 8192
        }
      }
    }
    backend: {
      request: {
        headers: []
        body: {
          bytes: 8192
        }
      }
      response: {
        headers: []
        body: {
          bytes: 8192
        }
      }
    }
  }
}]

resource serviceAPILocalDiagnostic 'Microsoft.ApiManagement/service/apis/diagnostics@2023-03-01-preview' = [for API in items(APIPolicies):{
  name: '${apiManagementName}/${API.value.name}/local'
  dependsOn: [apiManagementAPI]
  properties: {
    alwaysLog: 'allErrors'
    verbosity: 'verbose'
    logClientIp: true
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: {
        headers: []
        body: {
          bytes: 8192
        }
      }
      response: {
        headers: []
        body: {
          bytes: 8192
        }
      }
    }
    backend: {
      request: {
        headers: []
        body: {
          bytes: 8192
        }
      }
      response: {
        headers: []
        body: {
          bytes: 8192
        }
      }
    }
  }
}]
