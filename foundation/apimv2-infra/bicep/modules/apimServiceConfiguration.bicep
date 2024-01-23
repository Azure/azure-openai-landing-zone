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

//****************************************************************************************
// Variables
//****************************************************************************************

var openAIOpenAPISpec = loadTextContent('../artifacts/openAIOpenAPI.json')

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
// Resources
//****************************************************************************************

resource apiManagementAPI 'Microsoft.ApiManagement/service/apis@2023-03-01-preview' = {
  parent: existingApiManagement
  name: 'azure-openai-service-api'
  properties: {
    displayName: 'Azure OpenAI Service API'
    description: 'Azure OpenAI APIs for completions and search'
    format: 'openapi+json'
    value: openAIOpenAPISpec
    subscriptionRequired: true
    type: 'http'
    protocols: [
      'https'
    ]
    serviceUrl: existingApiManagement.properties.gatewayUrl
    path: 'openai'
  }
}

//********************************************
// Product
//********************************************

resource apiManagementProduct 'Microsoft.ApiManagement/service/products@2023-03-01-preview' = {
  parent: existingApiManagement
  name: 'openai'
  properties: {
    displayName: 'OpenAI'
    description: 'Echo for Azure OpenAI API Calls'
    subscriptionRequired: true
    approvalRequired: false
    state: 'published'
  }
}

resource apiManagementProductAPI 'Microsoft.ApiManagement/service/products/apis@2023-03-01-preview' = {
  parent: apiManagementProduct
  name: 'azure-openai-service-api'
}

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
// Policy Fragments
//********************************************

resource APIMChatCompletionEventHubLogger 'Microsoft.ApiManagement/service/policyfragments@2023-03-01-preview' = {
  parent: existingApiManagement
  name: 'ChatCompletionEventHubLogger'
  properties: {
    description: 'Sends usage information to an Event Hub named "event-hub-logger" for ChatCompletions calls. The code block checks for a false boolean value for "isStream" and then makes sure the call is not to a text-embedding-ada-002, dall-e-3, or whisper deployment-id'
    value: '<!--\r\n    IMPORTANT:\r\n    - Policy fragment are included as-is whenever they are referenced.\r\n    - If using variables. Ensure they are setup before use.\r\n    - Copy and paste your code here or simply start coding\r\n\r\n    Sends usage information to an Event Hub for ChatCompletions calls. The code block checks for a\r\n    false boolean value for "isStream" and then makes sure the call is not to a text-embedding-ada-002, dall-e-3, or whisper\r\n    deployment-id\r\n-->\r\n<fragment>\r\n\t<choose>\r\n\t\t<when condition="@(!context.Variables.GetValueOrDefault&lt;bool&gt;(&quot;isStream&quot;) &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) != &quot;text-embedding-ada-002&quot; || context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) != &quot;dall-e-3&quot; || context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) != &quot;whisper&quot;))">\r\n\t\t\t<log-to-eventhub logger-id="eventhub-logger" partition-id="0">@{\r\n                var responseBody = context.Response.Body?.As&lt;JObject&gt;(true);\r\n                return new JObject(\r\n                    new JProperty("event-time", DateTime.UtcNow.ToString()),\r\n                    new JProperty("operation", responseBody["object"].ToString()),\r\n                    new JProperty("model", responseBody["model"].ToString()),\r\n                    new JProperty("modeltime", context.Response.Headers.GetValueOrDefault("Openai-Processing-Ms",string.Empty)),\r\n                    new JProperty("completion_tokens", responseBody["usage"]["completion_tokens"].ToString()),\r\n                    new JProperty("prompt_tokens", responseBody["usage"]["prompt_tokens"].ToString()),\r\n                    new JProperty("total_tokens", responseBody["usage"]["total_tokens"].ToString())\r\n                ).ToString();\r\n            }</log-to-eventhub>\r\n\t\t</when>\r\n\t</choose>\r\n</fragment>'
  }
  dependsOn: [
    eventHubLogger
    namedValuesEndpoints
    namedValuesKeys
  ]
}

resource APIMEmbeddingsEventHubLogger 'Microsoft.ApiManagement/service/policyfragments@2023-03-01-preview' = {
  parent: existingApiManagement
  name: 'EmbeddingsEventHubLogger'
  properties: {
    description: 'Sends usage information to an Event Hub named "event-hub-logger" for Embeddings calls. The code block checks for a false boolean value for "isStream" and then makes sure the call is to a text-embedding-ada-002 deployment-id'
    value: '<!--\r\n    IMPORTANT:\r\n    - Policy fragment are included as-is whenever they are referenced.\r\n    - If using variables. Ensure they are setup before use.\r\n    - Copy and paste your code here or simply start coding\r\n\r\n    Sends usage information to an Event Hub for Embeddings calls. The code block checks for a false boolean value for "isStream" and then makes sure the call is to a text-embedding-ada-002 deployment-id\r\n-->\r\n<fragment>\r\n\t<choose>\r\n\t\t<when condition="@(!context.Variables.GetValueOrDefault&lt;bool&gt;(&quot;isStream&quot;) &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;text-embedding-ada-002&quot;))">\r\n\t\t\t<log-to-eventhub logger-id="eventhub-logger" partition-id="0">@{\r\n                var responseBody = context.Response.Body?.As&lt;JObject&gt;(true);\r\n                return new JObject(\r\n                    new JProperty("prompt_tokens", responseBody["usage"]["prompt_tokens"].ToString()),\r\n                    new JProperty("total_tokens", responseBody["usage"]["total_tokens"].ToString())\r\n                ).ToString();\r\n            }</log-to-eventhub>\r\n\t\t</when>\r\n\t</choose>\r\n</fragment>'
  }
  dependsOn: [ 
    eventHubLogger
    namedValuesEndpoints
    namedValuesKeys  
  ]
}

resource APIMDallE3Retry 'Microsoft.ApiManagement/service/policyfragments@2023-03-01-preview' = {
  parent: existingApiManagement
  name: 'DallE3Retry'
  properties: {
    description: 'Governs the retry policy and backendUrl resets when a 429 occurs for the dall-e-3 deployment-id'
    value: '<!--\r\n    IMPORTANT:\r\n    - Policy fragment are included as-is whenever they are referenced.\r\n    - If using variables. Ensure they are setup before use.\r\n    - Copy and paste your code here or simply start coding\r\n\r\n    Governs the retry policy and backendUrl resets when a 429 occurs for the dall-e-3 deployment-id\r\n-->\r\n<fragment>\r\n\t<retry condition="@(context.Response.StatusCode == 429 &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;dall-e-3&quot;))" count="4" interval="20" delta="10" first-fast-retry="false">\r\n\t\t<set-variable name="urlId" value="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) % 1 + 1)" />\r\n\t\t<choose>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-swedencentral-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t</choose>\r\n\t</retry>\r\n</fragment>'
  }
  dependsOn: [
    namedValuesEndpoints
    namedValuesKeys
  ]
}

resource APIMGpt35Turbo0301Retry 'Microsoft.ApiManagement/service/policyfragments@2023-03-01-preview' = {
  parent: existingApiManagement
  name: 'Gpt35Turbo0301Retry'
  properties: {
    description: 'Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-35-turbo-0301 deployment-id'
    value: '<!--\r\n    IMPORTANT:\r\n    - Policy fragment are included as-is whenever they are referenced.\r\n    - If using variables. Ensure they are setup before use.\r\n    - Copy and paste your code here or simply start coding\r\n\r\n    Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-35-turbo-0301 deployment-id\r\n-->\r\n<fragment>\r\n\t<retry condition="@(context.Response.StatusCode == 429 &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-0301&quot;))" count="4" interval="20" delta="10" first-fast-retry="false">\r\n\t\t<set-variable name="urlId" value="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) % 1 + 1)" />\r\n\t\t<choose>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">\r\n\t\t\t\t<set-backend-service base-url="{{aoai-westeurope-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-westeurope-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t</choose>\r\n\t</retry>\r\n</fragment>'
  }
  dependsOn: [     
    namedValuesEndpoints
    namedValuesKeys 
   ]
}

resource APIMGpt35Turbo0613Retry 'Microsoft.ApiManagement/service/policyfragments@2023-03-01-preview' = {
  parent: existingApiManagement
  name: 'Gpt35Turbo0613Retry'
  properties: {
    description: 'Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-35-turbo-0613 deployment-id'
    value: '<!--\r\n    IMPORTANT:\r\n    - Policy fragment are included as-is whenever they are referenced.\r\n    - If using variables. Ensure they are setup before use.\r\n    - Copy and paste your code here or simply start coding\r\n\r\n    Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-35-turbo-0613 deployment-id\r\n-->\r\n<fragment>\r\n\t<retry condition="@(context.Response.StatusCode == 429 &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-0613&quot;))" count="20" interval="4" delta="2" first-fast-retry="true">\r\n\t\t<set-variable name="urlId" value="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) % 10 + 1)" />\r\n\t\t<choose>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-australiaeast-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-canadaeast-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-eastus-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-eastus-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-eastus2-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-eastus2-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-francecentral-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-japaneast-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-japaneast-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 7)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-northcentral-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-northcentral-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 8)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-swedencentral-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 9)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-switzerlandnorth-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-switzerlandnorth-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 10)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-uksouth-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-uksouth-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t</choose>\r\n\t</retry>\r\n</fragment>'
  }
  dependsOn: [ 
    namedValuesEndpoints
    namedValuesKeys 
   ]
}

resource APIMGpt35Turbo1106Retry 'Microsoft.ApiManagement/service/policyfragments@2023-03-01-preview' = {
  parent: existingApiManagement
  name: 'Gpt35Turbo1106Retry'
  properties: {
    description: 'Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-35-turbo-1106 deployment-id'
    value: '<!--\r\n    IMPORTANT:\r\n    - Policy fragment are included as-is whenever they are referenced.\r\n    - If using variables. Ensure they are setup before use.\r\n    - Copy and paste your code here or simply start coding\r\n\r\n    Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-35-turbo-1106 deployment-id\r\n-->\r\n<fragment>\r\n\t<retry condition="@(context.Response.StatusCode == 429 &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-1106&quot;))" count="14" interval="10" delta="5" first-fast-retry="true">\r\n\t\t<set-variable name="urlId" value="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) % 7 + 1)" />\r\n\t\t<choose>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-australiaeast-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-canadaeast-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-francecentral-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-southindia-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-southindia-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-swedencentral-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-uksouth-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-uksouth-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 7)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-westus-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-westus-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t</choose>\r\n\t</retry>\r\n</fragment>'
  }
  dependsOn: [ 
    namedValuesEndpoints
    namedValuesKeys 
   ]
}

resource APIMGpt35Turbo16kRetry 'Microsoft.ApiManagement/service/policyfragments@2023-03-01-preview' = {
  parent: existingApiManagement
  name: 'Gpt35Turbo16kRetry'
  properties: {
    description: 'Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-35-turbo-16k deployment-id'
    value: '<!--\r\n    IMPORTANT:\r\n    - Policy fragment are included as-is whenever they are referenced.\r\n    - If using variables. Ensure they are setup before use.\r\n    - Copy and paste your code here or simply start coding\r\n\r\n    Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-35-turbo-16k deployment-id\r\n-->\r\n<fragment>\r\n\t<retry condition="@(context.Response.StatusCode == 429 &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-16k&quot;))" count="20" interval="4" delta="2" first-fast-retry="true">\r\n\t\t<set-variable name="urlId" value="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) % 10 + 1)" />\r\n\t\t<choose>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-australiaeast-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-canadaeast-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-eastus-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-eastus-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-eastus2-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-eastus2-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-francecentral-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-japaneast-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-japaneast-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 7)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-northcentral-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-northcentral-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 8)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-swedencentral-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 9)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-switzerlandnorth-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-switzerlandnorth-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 10)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-uksouth-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-uksouth-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t</choose>\r\n\t</retry>\r\n</fragment>'
  }
  dependsOn: [ 
    namedValuesEndpoints
    namedValuesKeys 
   ]
}

resource APIMGpt35TurboInstructRetry 'Microsoft.ApiManagement/service/policyfragments@2023-03-01-preview' = {
  parent: existingApiManagement
  name: 'Gpt35TurboInstructRetry'
  properties: {
    description: 'Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-35-turbo-instruct deployment-id'
    value: '<!--\r\n    IMPORTANT:\r\n    - Policy fragment are included as-is whenever they are referenced.\r\n    - If using variables. Ensure they are setup before use.\r\n    - Copy and paste your code here or simply start coding\r\n\r\n    Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-35-turbo-instruct deployment-id\r\n-->\r\n<fragment>\r\n\t<retry condition="@(context.Response.StatusCode == 429 &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-instruct&quot;))" count="4" interval="20" delta="10" first-fast-retry="true">\r\n\t\t<set-variable name="urlId" value="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) % 2 + 1)" />\r\n\t\t<choose>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-australiaeast-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-swedencentral-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t</choose>\r\n\t</retry>\r\n</fragment>'
  }
  dependsOn: [ 
    namedValuesEndpoints
    namedValuesKeys 
   ]
}

resource APIMGpt432kRetry 'Microsoft.ApiManagement/service/policyfragments@2023-03-01-preview' = {
  parent: existingApiManagement
  name: 'Gpt432kRetry'
  properties: {
    description: 'Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-4-32k deployment-id'
    value: '<!--\r\n    IMPORTANT:\r\n    - Policy fragment are included as-is whenever they are referenced.\r\n    - If using variables. Ensure they are setup before use.\r\n    - Copy and paste your code here or simply start coding\r\n\r\n    Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-4-32k deployment-id\r\n-->\r\n<fragment>\r\n\t<retry condition="@(context.Response.StatusCode == 429 &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-4-32k&quot;))" count="12" interval="10" delta="5" first-fast-retry="true">\r\n\t\t<set-variable name="urlId" value="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) % 6 + 1)" />\r\n\t\t<choose>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-australiaeast-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-canadaeast-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-eastus-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-eastus-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-francecentral-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-swedencentral-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-switzerlandnorth-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-switzerlandnorth-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t</choose>\r\n\t</retry>\r\n</fragment>'
  }
  dependsOn: [ 
    namedValuesEndpoints
    namedValuesKeys 
   ]
}

resource APIMGpt4Retry 'Microsoft.ApiManagement/service/policyfragments@2023-03-01-preview' = {
  parent: existingApiManagement
  name: 'Gpt4Retry'
  properties: {
    description: 'Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-4 deployment-id'
    value: '<!--\r\n    IMPORTANT:\r\n    - Policy fragment are included as-is whenever they are referenced.\r\n    - If using variables. Ensure they are setup before use.\r\n    - Copy and paste your code here or simply start coding\r\n\r\n    Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-4 deployment-id\r\n-->\r\n<fragment>\r\n\t<retry condition="@(context.Response.StatusCode == 429 &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-4&quot;))" count="12" interval="10" delta="5" first-fast-retry="true">\r\n\t\t<set-variable name="urlId" value="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) % 6 + 1)" />\r\n\t\t<choose>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-australiaeast-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-canadaeast-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-eastus-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-eastus-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-francecentral-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-swedencentral-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-switzerlandnorth-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-switzerlandnorth-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t</choose>\r\n\t</retry>\r\n</fragment>'
  }
  dependsOn: [ 
    namedValuesEndpoints
    namedValuesKeys 
   ]
}

resource APIMGpt4TurboRetry 'Microsoft.ApiManagement/service/policyfragments@2023-03-01-preview' = {
  parent: existingApiManagement
  name: 'Gpt4TurboRetry'
  properties: {
    description: 'Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-4-turbo deployment-id'
    value: '<!--\r\n    IMPORTANT:\r\n    - Policy fragment are included as-is whenever they are referenced.\r\n    - If using variables. Ensure they are setup before use.\r\n    - Copy and paste your code here or simply start coding\r\n\r\n    Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-4-turbo deployment-id\r\n-->\r\n<fragment>\r\n\t<retry condition="@(context.Response.StatusCode == 429 &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-4-turbo&quot;))" count="18" interval="4" delta="2" first-fast-retry="true">\r\n\t\t<set-variable name="urlId" value="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) % 9 + 1)" />\r\n\t\t<choose>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-australiaeast-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-canadaeast-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-eastus2-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-eastus2-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-francecentral-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-norwayeast-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-norwayeast-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-southindia-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-southindia-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 7)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-swedencentral-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 8)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-uksouth-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-uksouth-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 9)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-westus-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-westus-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t</choose>\r\n\t</retry>\r\n</fragment>'
  }
  dependsOn: [ 
    namedValuesEndpoints
    namedValuesKeys 
   ]
}

resource APIMGpt4vRetry 'Microsoft.ApiManagement/service/policyfragments@2023-03-01-preview' = {
  parent: existingApiManagement
  name: 'Gpt4vRetry'
  properties: {
    description: 'Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-4v deployment-id'
    value: '<!--\r\n    IMPORTANT:\r\n    - Policy fragment are included as-is whenever they are referenced.\r\n    - If using variables. Ensure they are setup before use.\r\n    - Copy and paste your code here or simply start coding\r\n\r\n    Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-4v deployment-id\r\n-->\r\n<fragment>\r\n\t<retry condition="@(context.Response.StatusCode == 429 &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-4v&quot;))" count="8" interval="15" delta="5" first-fast-retry="true">\r\n\t\t<set-variable name="urlId" value="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) % 4 + 1)" />\r\n\t\t<choose>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-australiaeast-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-swedencentral-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-switzerlandnorth-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-switzerlandnorth-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-westus-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-westus-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t</choose>\r\n\t</retry>\r\n</fragment>'
  }
  dependsOn: [ 
    namedValuesEndpoints
    namedValuesKeys 
   ]
}

resource APIMSetInitialBackendService 'Microsoft.ApiManagement/service/policyfragments@2023-03-01-preview' = {
  parent: existingApiManagement
  name: 'SetInitialBackendService'
  properties: {
    description: 'Evaluates the "aoaiModelName" variable and then the "urldId" variable to determine which backend service to utilize. Then it sets the appropriate "backendUrl" and api-key based on the Named values for the service'
    value: '<!--\r\n    IMPORTANT:\r\n    - Policy fragment are included as-is whenever they are referenced.\r\n    - If using variables. Ensure they are setup before use.\r\n    - Copy and paste your code here or simply start coding\r\n    \r\n    Evaluates the "aoaiModelName" variable and then the "urldId" variable to determine which backend service to utilize. Then it sets the appropriate "backendUrl" and api-key based on the Named values for the service\r\n-->\r\n<fragment>\r\n\t<choose>\r\n\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-0301&quot;)">\r\n\t\t\t<choose>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-westeurope-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-westeurope-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t</choose>\r\n\t\t</when>\r\n\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-0613&quot;)">\r\n\t\t\t<choose>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-australiaeast-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-canadaeast-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-eastus-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-eastus-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-eastus2-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-eastus2-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-francecentral-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-japaneast-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-japaneast-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 7)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-northcentral-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-northcentral-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 8)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-swedencentral-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 9)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-switzerlandnorth-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-switzerlandnorth-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 10)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-uksouth-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-uksouth-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t</choose>\r\n\t\t</when>\r\n\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-1106&quot;)">\r\n\t\t\t<choose>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-australiaeast-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-canadaeast-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-francecentral-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-southindia-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-southindia-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-swedencentral-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-uksouth-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-uksouth-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 7)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-westus-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-westus-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t</choose>\r\n\t\t</when>\r\n\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-16k&quot;)">\r\n\t\t\t<choose>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-australiaeast-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-canadaeast-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-eastus-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-eastus-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-eastus2-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-eastus2-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-francecentral-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-japaneast-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-japaneast-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 7)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-northcentral-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-northcentral-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 8)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-swedencentral-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 9)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-switzerlandnorth-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-switzerlandnorth-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 10)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-uksouth-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-uksouth-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t</choose>\r\n\t\t</when>\r\n\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-instruct&quot;)">\r\n\t\t\t<choose>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-australiaeast-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-swedencentral-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t</choose>\r\n\t\t</when>\r\n\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-4&quot;)">\r\n\t\t\t<choose>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-australiaeast-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-canadaeast-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-eastus-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-eastus-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-francecentral-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-swedencentral-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-switzerlandnorth-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-switzerlandnorth-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t</choose>\r\n\t\t</when>\r\n\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-4-32k&quot;)">\r\n\t\t\t<choose>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-australiaeast-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-canadaeast-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-eastus-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-eastus-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-francecentral-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-swedencentral-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-switzerlandnorth-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-switzerlandnorth-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t</choose>\r\n\t\t</when>\r\n\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-4-turbo&quot;)">\r\n\t\t\t<choose>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-australiaeast-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-canadaeast-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-eastus2-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-eastus2-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-francecentral-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-norwayeast-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-norwayeast-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-southindia-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-southindia-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 7)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-swedencentral-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 8)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-uksouth-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-uksouth-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 9)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-westus-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-westus-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t</choose>\r\n\t\t</when>\r\n\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-4v&quot;)">\r\n\t\t\t<choose>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-australiaeast-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-swedencentral-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-switzerlandnorth-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-switzerlandnorth-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-westus-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-westus-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t</choose>\r\n\t\t</when>\r\n\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;text-embedding-ada-002&quot;)">\r\n\t\t\t<choose>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-australiaeast-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-canadaeast-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-eastus-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-eastus-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-eastus2-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-eastus2-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-francecentral-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-japaneast-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-japaneast-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 7)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-northcentral-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-northcentral-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 8)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-norwayeast-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-norwayeast-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 9)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-southindia-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-southindia-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 10)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-swedencentral-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 11)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-switzerlandnorth-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-switzerlandnorth-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 12)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-uksouth-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-uksouth-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 13)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-westeurope-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-westeurope-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 14)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-westus-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-westus-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t</choose>\r\n\t\t</when>\r\n\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;dall-e-3&quot;)">\r\n\t\t\t<choose>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-swedencentral-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t</choose>\r\n\t\t</when>\r\n\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;whisper&quot;)">\r\n\t\t\t<choose>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-northcentral-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-northcentral-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">\r\n\t\t\t\t\t<set-variable name="backendUrl" value="{{aoai-westeurope-endpoint}}" />\r\n\t\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t\t<value>{{aoai-westeurope-key}}</value>\r\n\t\t\t\t\t</set-header>\r\n\t\t\t\t</when>\r\n\t\t\t</choose>\r\n\t\t</when>\r\n\t\t<otherwise>\r\n\t\t\t<set-variable name="backendUrl" value="{{aoai-eastus-endpoint}}" />\r\n\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t<value>{{aoai-eastus-key}}</value>\r\n\t\t\t</set-header>\r\n\t\t</otherwise>\r\n\t</choose>\r\n\t<set-backend-service base-url="@((string)context.Variables[&quot;backendUrl&quot;])" />\r\n</fragment>'
  }
  dependsOn: [ 
    namedValuesEndpoints
    namedValuesKeys 
   ]
}

resource APIMSetUrldIdVariable 'Microsoft.ApiManagement/service/policyfragments@2023-03-01-preview' = {
  parent: existingApiManagement
  name: 'SetUrldIdVariable'
  properties: {
    description: 'Sets the urlId variable, which is a randomly generated number based on the total number of endpoints being used to support an Azure OpenAI model.'
    value: '<!--\r\n    IMPORTANT:\r\n    - Policy fragment are included as-is whenever they are referenced.\r\n    - If using variables. Ensure they are setup before use.\r\n    - Copy and paste your code here or simply start coding\r\n-->\r\n<fragment>\r\n\t<choose>\r\n\t\t<!-- Sets the "urlId" variable to a random number generated via this function:\r\n        value="@(new Random(context.RequestId.GetHashCode()).Next(1, 2))"\r\n        as of Dec 14 2023\r\n        NOTE: \r\n                * When using this function the "@(context.Request.MatchedParameters["deployment-id"])" extracts\r\n                what is then evaluated against the variable "aoaiModelName".\r\n                * the values in .Next() are inclusive of the minimum and exlusive of the maximum\r\n                i.e. .Next(1, 2) implies 1 endpoint and .Next(1, 15) implies 14 endpoints\r\n\r\n        The "urlId" variable is used in the retry policy as well\r\n        -->\r\n\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-0301&quot;)">\r\n\t\t\t<set-variable name="urlId" value="@(new Random(context.RequestId.GetHashCode()).Next(1, 2))" />\r\n\t\t</when>\r\n\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-0613&quot;)">\r\n\t\t\t<set-variable name="urlId" value="@(new Random(context.RequestId.GetHashCode()).Next(1, 11))" />\r\n\t\t</when>\r\n\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-1106&quot;)">\r\n\t\t\t<set-variable name="urlId" value="@(new Random(context.RequestId.GetHashCode()).Next(1, 8))" />\r\n\t\t</when>\r\n\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-16k&quot;)">\r\n\t\t\t<set-variable name="urlId" value="@(new Random(context.RequestId.GetHashCode()).Next(1, 11))" />\r\n\t\t</when>\r\n\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-instruct&quot;)">\r\n\t\t\t<set-variable name="urlId" value="@(new Random(context.RequestId.GetHashCode()).Next(1, 3))" />\r\n\t\t</when>\r\n\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-4&quot;)">\r\n\t\t\t<set-variable name="urlId" value="@(new Random(context.RequestId.GetHashCode()).Next(1, 7))" />\r\n\t\t</when>\r\n\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-4-32k&quot;)">\r\n\t\t\t<set-variable name="urlId" value="@(new Random(context.RequestId.GetHashCode()).Next(1, 7))" />\r\n\t\t</when>\r\n\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-4-turbo&quot;)">\r\n\t\t\t<set-variable name="urlId" value="@(new Random(context.RequestId.GetHashCode()).Next(1, 10))" />\r\n\t\t</when>\r\n\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-4v&quot;)">\r\n\t\t\t<set-variable name="urlId" value="@(new Random(context.RequestId.GetHashCode()).Next(1, 5))" />\r\n\t\t</when>\r\n\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;text-embedding-ada-002&quot;)">\r\n\t\t\t<set-variable name="urlId" value="@(new Random(context.RequestId.GetHashCode()).Next(1, 15))" />\r\n\t\t</when>\r\n\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;dall-e-3&quot;)">\r\n\t\t\t<set-variable name="urlId" value="@(new Random(context.RequestId.GetHashCode()).Next(1, 2))" />\r\n\t\t</when>\r\n\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;whisper&quot;)">\r\n\t\t\t<set-variable name="urlId" value="@(new Random(context.RequestId.GetHashCode()).Next(1, 3))" />\r\n\t\t</when>\r\n\t</choose>\r\n</fragment>'
  }
  dependsOn: [ 
    namedValuesEndpoints
    namedValuesKeys 
   ]
}

resource APIMTextEmbeddingAda002Retry 'Microsoft.ApiManagement/service/policyfragments@2023-03-01-preview' = {
  parent: existingApiManagement
  name: 'TextEmbeddingAda002Retry'
  properties: {
    description: 'Governs the retry policy and backendUrl resets when a 429 occurs for the text-embedding-ada-002 deployment-id'
    value: '<!--\r\n    IMPORTANT:\r\n    - Policy fragment are included as-is whenever they are referenced.\r\n    - If using variables. Ensure they are setup before use.\r\n    - Copy and paste your code here or simply start coding\r\n\r\n    Governs the retry policy and backendUrl resets when a 429 occurs for the text-embedding-ada-002 deployment-id\r\n-->\r\n<fragment>\r\n\t<retry condition="@(context.Response.StatusCode == 429 &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;text-embedding-ada-002&quot;))" count="28" interval="4" delta="2" first-fast-retry="true">\r\n\t\t<set-variable name="urlId" value="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) % 14 + 1)" />\r\n\t\t<choose>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-australiaeast-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-canadaeast-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-eastus-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-eastus-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-eastus2-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-eastus2-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-francecentral-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-japaneast-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-japaneast-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 7)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-northcentral-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-northcentral-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 8)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-norwayeast-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-norwayeast-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 9)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-southindia-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-southindia-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 10)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-swedencentral-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 11)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-switzerlandnorth-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-switzerlandnorth-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 12)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-uksouth-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-uksouth-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 13)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-westeurope-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-westeurope-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 14)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-westus-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-westus-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t</choose>\r\n\t</retry>\r\n</fragment>'
  }
  dependsOn: [ 
    namedValuesEndpoints
    namedValuesKeys 
   ]
}

resource APIMWhisperRetry 'Microsoft.ApiManagement/service/policyfragments@2023-03-01-preview' = {
  parent: existingApiManagement
  name: 'WhisperRetry'
  properties: {
    description: 'Governs the retry policy and backendUrl resets when a 429 occurs for the whisper deployment-id'
    value: '<!--\r\n    IMPORTANT:\r\n    - Policy fragment are included as-is whenever they are referenced.\r\n    - If using variables. Ensure they are setup before use.\r\n    - Copy and paste your code here or simply start coding\r\n\r\n    Governs the retry policy and backendUrl resets when a 429 occurs for the whisper deployment-id\r\n-->\r\n<fragment>\r\n\t<retry condition="@(context.Response.StatusCode == 429 &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;whisper&quot;))" count="4" interval="15" delta="5" first-fast-retry="true">\r\n\t\t<set-variable name="urlId" value="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) % 2 + 1)" />\r\n\t\t<choose>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-northcentral-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-northcentral-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t\t<when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">\r\n\t\t\t\t<set-variable name="backendUrl" value="{{aoai-westeurope-endpoint}}" />\r\n\t\t\t\t<set-header name="api-key" exists-action="override">\r\n\t\t\t\t\t<value>{{aoai-westeurope-key}}</value>\r\n\t\t\t\t</set-header>\r\n\t\t\t</when>\r\n\t\t</choose>\r\n\t</retry>\r\n</fragment>'
  }
  dependsOn: [ 
    namedValuesEndpoints
    namedValuesKeys 
   ]
}

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

resource serviceAPIAppInsightsDiagnostic 'Microsoft.ApiManagement/service/apis/diagnostics@2023-03-01-preview' = {
  parent: apiManagementAPI
  name: 'applicationinsights'
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
}

resource serviceAPIAzureMonitorDiagnostic 'Microsoft.ApiManagement/service/apis/diagnostics@2023-03-01-preview' = {
  parent: apiManagementAPI
  name: 'azuremonitor'
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
}

resource serviceAPILocalDiagnostic 'Microsoft.ApiManagement/service/apis/diagnostics@2023-03-01-preview' = {
  parent: apiManagementAPI
  name: 'local'
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
}
