resource "azurerm_api_management_api" "openai" {
  name                  = "azure-openai-service-api"
  resource_group_name   = var.resource_group_name
  api_management_name   = var.apim_name
  revision              = "1"
  display_name          = "Azure OpenAI Service API"
  description           = "Azure OpenAI APIs for completions and search"
  path                  = "openai"
  protocols             = ["https"]
  subscription_required = true
  subscription_key_parameter_names {
    header = "api-key"
    query  = "subscription-key"
  }
  service_url = var.gatewayUrl

  import {
    content_format = "openapi-link"
    content_value  = "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2023-05-15/inference.json"
  }
}

resource "azurerm_api_management_product" "openai" {
  product_id            = "OpenAI"
  api_management_name   = var.apim_name
  resource_group_name   = var.resource_group_name
  display_name          = "Echo for Azure OpenAI API Calls"
  subscription_required = true
  approval_required     = false
  published             = true
}

resource "azurerm_api_management_product_api" "openai" {
  api_name            = azurerm_api_management_api.openai.name
  product_id          = azurerm_api_management_product.openai.product_id
  api_management_name = var.apim_name
  resource_group_name = var.resource_group_name
}

# Already Exists in a new APIM
# resource "azurerm_api_management_product_group" "admin" {
#   product_id          = azurerm_api_management_product.openai.product_id
#   group_name          = "administrators"
#   api_management_name = var.apim_name
#   resource_group_name = var.resource_group_name
# }

resource "azurerm_api_management_subscription" "dev" {
  api_management_name = var.apim_name
  resource_group_name = var.resource_group_name
  product_id          = azurerm_api_management_product.openai.id
  display_name        = "aoai-dev-subscription"
  allow_tracing       = false
}

resource "azurerm_api_management_subscription" "prod" {
  api_management_name = var.apim_name
  resource_group_name = var.resource_group_name
  product_id          = azurerm_api_management_product.openai.id
  display_name        = "aoai-prod-subscription"
  allow_tracing       = false
}

resource "azurerm_api_management_named_value" "values" {
  for_each            = var.secrets
  name                = each.value.endpointName
  resource_group_name = var.resource_group_name
  api_management_name = var.apim_name
  display_name        = each.value.endpointName
  value               = each.value.endpointURL
  secret              = false
}

resource "azurerm_api_management_named_value" "secrets" {
  for_each            = var.secrets
  name                = each.value.secretName
  resource_group_name = var.resource_group_name
  api_management_name = var.apim_name
  display_name        = each.value.secretName
  secret              = true
  value_from_key_vault {
    secret_id = "https://${var.keyvault_name}.vault.azure.net/secrets/${each.value.secretName}"
  }
}

resource "azurerm_api_management_logger" "appi_logger" {
  name                = "appinsights-logger"
  api_management_name = var.apim_name
  resource_group_name = var.resource_group_name
  resource_id         = var.appi_resource_id

  application_insights {
    instrumentation_key = var.appi_instrumentation_key
  }
}

resource "azurerm_api_management_logger" "evh_logger" {
  name                = "eventhub-logger"
  api_management_name = var.apim_name
  resource_group_name = var.resource_group_name

  eventhub {
    connection_string = var.eventhub_connection_string
    name              = var.eventhub_name
  }
}

# Already Exists in a new APIM?
data "azapi_resource" "azure_monitor_logger" {
  name      = "azuremonitor"
  parent_id = var.apim_id
  type      = "Microsoft.ApiManagement/service/loggers@2023-05-01-preview"
}

resource "azurerm_api_management_diagnostic" "appi_diagnostics" {
  identifier               = "applicationinsights"
  api_management_name      = var.apim_name
  resource_group_name      = var.resource_group_name
  api_management_logger_id = azurerm_api_management_logger.appi_logger.id

  sampling_percentage       = 100
  always_log_errors         = true
  log_client_ip             = true
  verbosity                 = "information"
  http_correlation_protocol = "W3C"

  frontend_request {
    body_bytes     = 8192
    headers_to_log = []
    data_masking {
      query_params {
        mode  = "Hide"
        value = "*"
      }
    }
  }

  frontend_response {
    body_bytes     = 8192
    headers_to_log = []
  }

  backend_request {
    body_bytes     = 8192
    headers_to_log = []
    data_masking {
      query_params {
        mode  = "Hide"
        value = "*"
      }
    }
  }

  backend_response {
    body_bytes     = 8192
    headers_to_log = []
  }
}

# Already Exists in a new APIM?
# resource "azurerm_api_management_diagnostic" "azure_monitor_diagnostics" {
#   identifier               = "azuremonitor"
#   api_management_name      = var.apim_name
#   resource_group_name      = var.resource_group_name
#   api_management_logger_id = data.azapi_resource.azure_monitor_logger.id

#   sampling_percentage = 100
#   always_log_errors   = true
#   log_client_ip       = true
#   # verbosity                 = "information"
#   # http_correlation_protocol = "W3C"

#   frontend_request {
#     body_bytes     = 8192
#     headers_to_log = []
#     data_masking {
#       query_params {
#         mode  = "Hide"
#         value = "*"
#       }
#     }
#   }

#   frontend_response {
#     body_bytes     = 8192
#     headers_to_log = []
#   }

#   backend_request {
#     body_bytes     = 8192
#     headers_to_log = []
#     data_masking {
#       query_params {
#         mode  = "Hide"
#         value = "*"
#       }
#     }
#   }

#   backend_response {
#     body_bytes     = 8192
#     headers_to_log = []
#   }
# }

resource "azurerm_api_management_api_policy" "policy" {
  api_name            = azurerm_api_management_api.openai.name
  api_management_name = var.apim_name
  resource_group_name = var.resource_group_name

  xml_content = <<XML
    <!--
        IMPORTANT:
        - Policy elements can appear only within the <inbound>, <outbound>, <backend> section elements.
        - To apply a policy to the incoming request (before it is forwarded to the backend service), place a corresponding policy element within the <inbound> section element.
        - To apply a policy to the outgoing response (before it is sent back to the caller), place a corresponding policy element within the <outbound> section element.
        - To add a policy, place the cursor at the desired insertion point and select a policy from the sidebar.
        - To remove a policy, delete the corresponding policy statement from the policy document.
        - Position the <base> element within a section element to inherit all policies from the corresponding section element in the enclosing scope.
        - Remove the <base> element to prevent inheriting policies from the corresponding section element in the enclosing scope.
        - Policies are applied in the order of their appearance, from the top down.
        - Comments within policy elements are not supported and may disappear. Place your comments between policy elements or at a higher level scope.
    API-M RETRY LOGIC FOR AZURE OPEN AI SERVICE NOTES - 12/13/2023
    This code defines an Azure API Management Service policy configuration that dynamically routes API requests to different backend services based on the "deployment-id" parameter. 
    The routing logic uses a random number generator to distribute the requests among the available backend services for each deployment model. 
    The policy also implements a retry mechanism for handling rate-limiting (HTTP 429) responses. 
    Here\'s a summary of the policy behavior:
    1. Extracts the \"deployment-id\" parameter from the incoming request.
    2. Based on the \"deployment-id\", the policy determines which backend services are available for the specific model.
    3. Selects a backend service using a random number generator and sets that to a variable urlId.
    4. Sets the backend service URL and API key based on the selected backend service identified by the urlId.
    5. Performs cache lookup to check if a cached response is available.
    6. Implements a retry mechanism for rate-limiting (HTTP 429) responses, adjusting the backend service selection for each retry attempt.
    7. Stores successful responses in the cache for 20 minutes.
    This policy ensures efficient load distribution among backend services, provides a robust retry mechanism for handling rate-limiting, and leverages caching to improve overall performance.
    NOTE:
    The \"deployment-id\" variable is capturing and evaluating the name of the model as you created it - so if you named it \"custom-gpt-35-turbo\" instead of \"gpt-35-turbo\" you will need to edit the policies below. This code assumes all models are deployed as named and that each model is deployed in each region only once.
    PLEASE NOTE THAT WHEN YOU CHANGE THE NUMBER OF ENDPOINTS BEING USED !!!
    You will need to edit the code for every time you both set and evaluate \"urlId\" to make sure you are using the correct number of endpoints - whenever you 
    use (new Random(context.RequestId.GetHashCode()).Next or (context.Variables.GetValueOrDefault<int>(\"urlId\"). 
    If you have 5 endpoints, the initial .Next should have (1, 6) as it\'s inclusive of 1 and exclusive of the top-end 6. 
    The GetValueOrDefault<int>(\"urlId\") then evaluates and adds 1, so not setting the numbers properly may evaluate to a non-existent \"urlId\" and throws a 500 response code.
    -->
    <policies>
      <inbound>
        <base />
        <!-- Extracting the \"deployment-id\" parameter from the incoming request and setting it to the aoaiModelName variable.
                 This represents the name under which the model is deployed; it should be the same in ALL regions you wish to allow
                 endpoint selection and retries in -->
        <set-variable name="aoaiModelName" value="@(context.Request.MatchedParameters[&quot;deployment-id&quot;])" />
        <!-- Determines whether an inbound request has streaming set to true; if the inbound call is set to stream,
                 then we do not send the results to our Event Hub logger\\
                 See https://journeyofthegeek.com/2023/11/10/the-challenge-of-logging-azure-openai-stream-completions/
                 or
                 https://github.com/timoklimmer/powerproxy-aoai
                 on ways to handle streaming results for logging purposes -->
        <set-variable name="isStream" value="@(context.Request.Body.As&lt;JObject&gt;(true)[&quot;stream&quot;].Value&lt;bool&gt;())" />
        <choose>
          <when condition="@(!string.IsNullOrEmpty(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;)))">
            <!-- Determining the number of backend services available for the specific model based on the \"deployment-id\"
                        and then setting that randomly generated number to the urlId variable -->
            <include-fragment fragment-id="SetUrldIdVariable" />
            <!-- Evaluates the \"aoaiModelName\" variable and then the \"urldId\" variable to determine which backend service to utilize. Then it sets the appropriate \"backendUrl\" and api-key based on the Named values for the service -->
            <include-fragment fragment-id="SetInitialBackendService" />
          </when>
        </choose>
        <cache-lookup vary-by-developer="false" vary-by-developer-groups="false" downstream-caching-type="none">
          <vary-by-header>Accept</vary-by-header>
          <vary-by-header>Accept-Charset</vary-by-header>
          <vary-by-header>Authorization</vary-by-header>
        </cache-lookup>
      </inbound>
      <backend>
        <base />
      </backend>
      <!-- 
    The retry is set to automatically retry the request when the following conditions are met:
    The response status code is 429 (Too Many Requests): 
    This usually indicates that the client has sent too many requests in a given amount of time, and the server is rate-limiting the requests.
    AND
    The deployment-id evaluates to be a certain model type - it should not get to the point of hitting the retry policy if there is no deploment-id matching what is provided in the initial request.
    Retry Policy Definitions:
    count: This attribute specifies the maximum number of retries that the policy will attempt if the specified condition is met. 
    For example, if count=\"5\", the policy will retry up to 5 times.
    interval: This attribute specifies the time interval (in seconds) between each retry attempt. 
    If interval=\"1\", there will be a 1-second delay between retries.
    delta: This attribute specifics the time (in seconds) to be added after each subsequent retry attempt; it does not apply between the first and second retry attempts if first-fast-try is set to true.
    first-fast-retry: This attribute, when set to true, allows the first retry attempt to happen immediately, without waiting for 
    the specified interval. If set to false, all retry attempts will wait for the interval duration before being executed.
    When the retry policy is triggered, it will execute the logic inside the <choose> block to modify the backend service URL and API key based on the value of the urlId variable. This effectively changes the backend service to which the request will be retried, in case the initial backend service returns a 429 status code.
    The Backend Service, governed by the \"backendUrl\", is selected based on the \"urlId\" variable. With each subsequent retry, \"urlId\" is incremented by 1. There are different retry blocks for each model as each model has different Token Per Minute (TPM) rates and number of regions that serve that model. 
    Therefore, to allow for different retry rates, the models enter different retry blocks with different settings for the retry. You may wish to modify those settings based on your application and requirements.
    PLEASE NOTE THAT WHEN YOU CHANGE THE NUMBER OF ENDPOINTS BEING USED !!!
    You will need to edit the code for every time you both set and evaluate \"urlId\" to make sure you are using the correct number of endpoints - whenever you 
    use (new Random(context.RequestId.GetHashCode()).Next or (context.Variables.GetValueOrDefault<int>(\"urlId\"). 
    If you have 5 endpoints, the initial .Next should have (1, 6) as it\'s inclusive of 1 and exclusive of the top-end 6. 
    The GetValueOrDefault<int>(\"urlId\") then evaluates and adds 1, so not setting the numbers properly may evaluate to a non-existent \"urlId\" and throws a 500 response code.
    -->
      <outbound>
        <base />
        <include-fragment fragment-id="Gpt35Turbo0301Retry" />
        <include-fragment fragment-id="Gpt35Turbo0613Retry" />
        <include-fragment fragment-id="Gpt35Turbo1106Retry" />
        <include-fragment fragment-id="Gpt35Turbo16kRetry" />
        <include-fragment fragment-id="Gpt35TurboInstructRetry" />
        <include-fragment fragment-id="Gpt4Retry" />
        <include-fragment fragment-id="Gpt432kRetry" />
        <include-fragment fragment-id="Gpt4TurboRetry" />
        <include-fragment fragment-id="Gpt4vRetry" />
        <include-fragment fragment-id="TextEmbeddingAda002Retry" />
        <include-fragment fragment-id="DallE3Retry" />
        <include-fragment fragment-id="WhisperRetry" />
        <set-header name="Backend-Service-URL" exists-action="override">
          <value>@((string)context.Variables["backendUrl"])</value>
        </set-header>
        <cache-store duration="20" />
        <include-fragment fragment-id="ChatCompletionEventHubLogger" />
        <include-fragment fragment-id="EmbeddingsEventHubLogger" />
      </outbound>
      <on-error>
        <base />
      </on-error>
    </policies>
    XML
  depends_on = [
    azapi_resource.chat_completion_event_hub_logger,
    azapi_resource.embeddings_event_hub_logger,
    azapi_resource.dall_e3_retry,
    azapi_resource.gpt_35_turbo_0301_retry,
    azapi_resource.gpt_35_turbo_0613_retry,
    azapi_resource.gpt_35_turbo_1106_retry,
    azapi_resource.gpt_35_turbo_16k_retry,
    azapi_resource.gpt_35_turbo_instruct_retry,
    azapi_resource.gpt_4_retry,
    azapi_resource.gpt_4_32k_retry,
    azapi_resource.gpt_4_turbo_retry,
    azapi_resource.gpt_4_v_retry,
    azapi_resource.text_embedding_ada_002_retry,
    azapi_resource.whisper_retry
  ]
}

resource "azapi_resource" "chat_completion_event_hub_logger" {
  type                      = "Microsoft.ApiManagement/service/policyFragments@2023-05-01-preview"
  name                      = "ChatCompletionEventHubLogger"
  parent_id                 = var.apim_id
  schema_validation_enabled = false
  body = jsonencode({
    properties = {
      description = "Sends usage information to an Event Hub named \"event-hub-logger\" for ChatCompletions calls. The code block checks for a false boolean value for \"isStream\" and then makes sure the call is not to a text-embedding-ada-002, dall-e-3, or whisper deployment-id"
      format      = "xml"
      value       = <<XML
        <!--
            IMPORTANT:
            - Policy fragment are included as-is whenever they are referenced.
            - If using variables. Ensure they are setup before use.
            - Copy and paste your code here or simply start coding
            Sends usage information to an Event Hub for ChatCompletions calls. The code block checks for a
            false boolean value for "isStream" and then makes sure the call is not to a text-embedding-ada-002, dall-e-3, or whisper
            deployment-id
        -->
        <fragment>
          <choose>
            <when condition="@(!context.Variables.GetValueOrDefault&lt;bool&gt;(&quot;isStream&quot;) &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) != &quot;text-embedding-ada-002&quot; || context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) != &quot;dall-e-3&quot; || context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) != &quot;whisper&quot;))">
              <log-to-eventhub logger-id="eventhub-logger" partition-id="0">@{
                          var responseBody = context.Response.Body?.As&lt;JObject&gt;(true);
                        return new JObject(
                              new JProperty("event-time", DateTime.UtcNow.ToString()),
                            new JProperty("operation", responseBody["object"].ToString()),
                            new JProperty("model", responseBody["model"].ToString()),
                            new JProperty("modeltime", context.Response.Headers.GetValueOrDefault("Openai-Processing-Ms",string.Empty)),
                            new JProperty("completion_tokens", responseBody["usage"]["completion_tokens"].ToString()),
                            new JProperty("prompt_tokens", responseBody["usage"]["prompt_tokens"].ToString()),
                            new JProperty("total_tokens", responseBody["usage"]["total_tokens"].ToString())
                        ).ToString();
                    }</log-to-eventhub>
            </when>
          </choose>
        </fragment>
        XML
    }
  })
  depends_on = [
    azurerm_api_management_logger.evh_logger,
    azurerm_api_management_named_value.values,
    azurerm_api_management_named_value.secrets
  ]
  lifecycle {
    ignore_changes = [body]
  }
}

resource "azapi_resource" "embeddings_event_hub_logger" {
  type                      = "Microsoft.ApiManagement/service/policyFragments@2023-05-01-preview"
  name                      = "EmbeddingsEventHubLogger"
  parent_id                 = var.apim_id
  schema_validation_enabled = false
  body = jsonencode({
    properties = {
      description = "Sends usage information to an Event Hub named \"event-hub-logger\" for Embeddings calls. The code block checks for a false boolean value for \"isStream\" and then makes sure the call is to a text-embedding-ada-002 deployment-id"
      format      = "xml"
      value       = <<XML
        <!--
            IMPORTANT:
            - Policy fragment are included as-is whenever they are referenced.
            - If using variables. Ensure they are setup before use.
            - Copy and paste your code here or simply start coding
            Sends usage information to an Event Hub for Embeddings calls. The code block checks for a false boolean value for "isStream" and then makes sure the call is to a text-embedding-ada-002 deployment-id
        -->
        <fragment>
          <choose>
            <when condition="@(!context.Variables.GetValueOrDefault&lt;bool&gt;(&quot;isStream&quot;) &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;text-embedding-ada-002&quot;))">
              <log-to-eventhub logger-id="eventhub-logger" partition-id="0">@{
                          var responseBody = context.Response.Body?.As&lt;JObject&gt;(true);
                        return new JObject(
                              new JProperty("prompt_tokens", responseBody["usage"]["prompt_tokens"].ToString()),
                            new JProperty("total_tokens", responseBody["usage"]["total_tokens"].ToString())
                        ).ToString();
                    }</log-to-eventhub>
            </when>
          </choose>
        </fragment>
        XML
    }
  })
  depends_on = [
    azurerm_api_management_logger.evh_logger,
    azurerm_api_management_named_value.values,
    azurerm_api_management_named_value.secrets
  ]
  lifecycle {
    ignore_changes = [body]
  }
}

resource "azapi_resource" "dall_e3_retry" {
  type                      = "Microsoft.ApiManagement/service/policyFragments@2023-05-01-preview"
  name                      = "DallE3Retry"
  parent_id                 = var.apim_id
  schema_validation_enabled = false
  body = jsonencode({
    properties = {
      description = "Governs the retry policy and backendUrl resets when a 429 occurs for the dall-e-3 deployment-id"
      format      = "xml"
      value       = <<XML
        <!--
            IMPORTANT:
            - Policy fragment are included as-is whenever they are referenced.
            - If using variables. Ensure they are setup before use.
            - Copy and paste your code here or simply start coding
            Governs the retry policy and backendUrl resets when a 429 occurs for the dall-e-3 deployment-id
        -->
        <fragment>
          <retry condition="@(context.Response.StatusCode == 429 &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;dall-e-3&quot;))" count="4" interval="20" delta="10" first-fast-retry="false">
            <set-variable name="urlId" value="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) % 1 + 1)" />
            <choose>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">
                <set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-swedencentral-key}}</value>
                </set-header>
              </when>
            </choose>
          </retry>
        </fragment>
        XML
    }
  })
  depends_on = [
    azurerm_api_management_named_value.values,
    azurerm_api_management_named_value.secrets
  ]
  lifecycle {
    ignore_changes = [body]
  }
}

resource "azapi_resource" "gpt_35_turbo_0301_retry" {
  type                      = "Microsoft.ApiManagement/service/policyFragments@2023-05-01-preview"
  name                      = "Gpt35Turbo0301Retry"
  parent_id                 = var.apim_id
  schema_validation_enabled = false
  body = jsonencode({
    properties = {
      description = "Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-35-turbo-0301 deployment-id"
      format      = "xml"
      value       = <<XML
        <!--
            IMPORTANT:
            - Policy fragment are included as-is whenever they are referenced.
            - If using variables. Ensure they are setup before use.
            - Copy and paste your code here or simply start coding
            Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-35-turbo-0301 deployment-id
        -->
        <fragment>
          <retry condition="@(context.Response.StatusCode == 429 &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-0301&quot;))" count="4" interval="20" delta="10" first-fast-retry="false">
            <set-variable name="urlId" value="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) % 1 + 1)" />
            <choose>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">
                <set-backend-service base-url="{{aoai-westeurope-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-westeurope-key}}</value>
                </set-header>
              </when>
            </choose>
          </retry>
        </fragment>
        XML
    }
  })
  depends_on = [
    azurerm_api_management_named_value.values,
    azurerm_api_management_named_value.secrets
  ]
  lifecycle {
    ignore_changes = [body]
  }
}

resource "azapi_resource" "gpt_35_turbo_0613_retry" {
  type                      = "Microsoft.ApiManagement/service/policyFragments@2023-05-01-preview"
  name                      = "Gpt35Turbo0613Retry"
  parent_id                 = var.apim_id
  schema_validation_enabled = false
  body = jsonencode({
    properties = {
      description = "Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-35-turbo-0613 deployment-id"
      format      = "xml"
      value       = <<XML
        <!--
            IMPORTANT:
            - Policy fragment are included as-is whenever they are referenced.
            - If using variables. Ensure they are setup before use.
            - Copy and paste your code here or simply start coding
            Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-35-turbo-0613 deployment-id
        -->
        <fragment>
          <retry condition="@(context.Response.StatusCode == 429 &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-0613&quot;))" count="20" interval="4" delta="2" first-fast-retry="true">
            <set-variable name="urlId" value="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) % 10 + 1)" />
            <choose>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">
                <set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-australiaeast-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">
                <set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-canadaeast-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">
                <set-variable name="backendUrl" value="{{aoai-eastus-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-eastus-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">
                <set-variable name="backendUrl" value="{{aoai-eastus2-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-eastus2-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">
                <set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-francecentral-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">
                <set-variable name="backendUrl" value="{{aoai-japaneast-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-japaneast-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 7)">
                <set-variable name="backendUrl" value="{{aoai-northcentral-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-northcentral-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 8)">
                <set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-swedencentral-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 9)">
                <set-variable name="backendUrl" value="{{aoai-switzerlandnorth-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-switzerlandnorth-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 10)">
                <set-variable name="backendUrl" value="{{aoai-uksouth-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-uksouth-key}}</value>
                </set-header>
              </when>
            </choose>
          </retry>
        </fragment>
        XML
    }
  })
  depends_on = [
    azurerm_api_management_named_value.values,
    azurerm_api_management_named_value.secrets
  ]
  lifecycle {
    ignore_changes = [body]
  }
}

resource "azapi_resource" "gpt_35_turbo_1106_retry" {
  type                      = "Microsoft.ApiManagement/service/policyFragments@2023-05-01-preview"
  name                      = "Gpt35Turbo1106Retry"
  parent_id                 = var.apim_id
  schema_validation_enabled = false
  body = jsonencode({
    properties = {
      description = "Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-35-turbo-1106 deployment-id"
      format      = "xml"
      value       = <<XML
        <!--
            IMPORTANT:
            - Policy fragment are included as-is whenever they are referenced.
            - If using variables. Ensure they are setup before use.
            - Copy and paste your code here or simply start coding
        
            Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-35-turbo-1106 deployment-id
        -->
        <fragment>
          <retry condition="@(context.Response.StatusCode == 429 &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-1106&quot;))" count="14" interval="10" delta="5" first-fast-retry="true">
            <set-variable name="urlId" value="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) % 7 + 1)" />
            <choose>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">
                <set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-australiaeast-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">
                <set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-canadaeast-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">
                <set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-francecentral-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">
                <set-variable name="backendUrl" value="{{aoai-southindia-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-southindia-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">
                <set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-swedencentral-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">
                <set-variable name="backendUrl" value="{{aoai-uksouth-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-uksouth-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 7)">
                <set-variable name="backendUrl" value="{{aoai-westus-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-westus-key}}</value>
                </set-header>
              </when>
            </choose>
          </retry>
        </fragment>
        XML
    }
  })
  depends_on = [
    azurerm_api_management_named_value.values,
    azurerm_api_management_named_value.secrets
  ]
  lifecycle {
    ignore_changes = [body]
  }
}

resource "azapi_resource" "gpt_35_turbo_16k_retry" {
  type                      = "Microsoft.ApiManagement/service/policyFragments@2023-05-01-preview"
  name                      = "Gpt35Turbo16kRetry"
  parent_id                 = var.apim_id
  schema_validation_enabled = false
  body = jsonencode({
    properties = {
      description = "Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-35-turbo-16k deployment-id"
      format      = "xml"
      value       = <<XML
        <!--
            IMPORTANT:
            - Policy fragment are included as-is whenever they are referenced.
            - If using variables. Ensure they are setup before use.
            - Copy and paste your code here or simply start coding
            Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-35-turbo-16k deployment-id
        -->
        <fragment>
          <retry condition="@(context.Response.StatusCode == 429 &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-16k&quot;))" count="20" interval="4" delta="2" first-fast-retry="true">
            <set-variable name="urlId" value="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) % 10 + 1)" />
            <choose>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">
                <set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-australiaeast-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">
                <set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-canadaeast-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">
                <set-variable name="backendUrl" value="{{aoai-eastus-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-eastus-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">
                <set-variable name="backendUrl" value="{{aoai-eastus2-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-eastus2-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">
                <set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-francecentral-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">
                <set-variable name="backendUrl" value="{{aoai-japaneast-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-japaneast-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 7)">
                <set-variable name="backendUrl" value="{{aoai-northcentral-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-northcentral-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 8)">
                <set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-swedencentral-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 9)">
                <set-variable name="backendUrl" value="{{aoai-switzerlandnorth-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-switzerlandnorth-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 10)">
                <set-variable name="backendUrl" value="{{aoai-uksouth-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-uksouth-key}}</value>
                </set-header>
              </when>
            </choose>
          </retry>
        </fragment>
        XML
    }
  })
  depends_on = [
    azurerm_api_management_named_value.values,
    azurerm_api_management_named_value.secrets
  ]
  lifecycle {
    ignore_changes = [body]
  }
}

resource "azapi_resource" "gpt_35_turbo_instruct_retry" {
  type                      = "Microsoft.ApiManagement/service/policyFragments@2023-05-01-preview"
  name                      = "Gpt35TurboInstructRetry"
  parent_id                 = var.apim_id
  schema_validation_enabled = false
  body = jsonencode({
    properties = {
      description = "Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-35-turbo-instruct deployment-id"
      format      = "xml"
      value       = <<XML
        <!--
            IMPORTANT:
            - Policy fragment are included as-is whenever they are referenced.
            - If using variables. Ensure they are setup before use.
            - Copy and paste your code here or simply start coding
        
            Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-35-turbo-instruct deployment-id
        -->
        <fragment>
          <retry condition="@(context.Response.StatusCode == 429 &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-instruct&quot;))" count="4" interval="20" delta="10" first-fast-retry="true">
            <set-variable name="urlId" value="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) % 2 + 1)" />
            <choose>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">
                <set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-australiaeast-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">
                <set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-swedencentral-key}}</value>
                </set-header>
              </when>
            </choose>
          </retry>
        </fragment>
        XML
    }
  })
  depends_on = [
    azurerm_api_management_named_value.values,
    azurerm_api_management_named_value.secrets
  ]
  lifecycle {
    ignore_changes = [body]
  }
}

resource "azapi_resource" "gpt_4_32k_retry" {
  type                      = "Microsoft.ApiManagement/service/policyFragments@2023-05-01-preview"
  name                      = "Gpt432kRetry"
  parent_id                 = var.apim_id
  schema_validation_enabled = false
  body = jsonencode({
    properties = {
      description = "Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-4-32k deployment-id"
      format      = "xml"
      value       = <<XML
        <!--
            IMPORTANT:
            - Policy fragment are included as-is whenever they are referenced.
            - If using variables. Ensure they are setup before use.
            - Copy and paste your code here or simply start coding
            Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-4-32k deployment-id
        -->
        <fragment>
          <retry condition="@(context.Response.StatusCode == 429 &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-4-32k&quot;))" count="12" interval="10" delta="5" first-fast-retry="true">
            <set-variable name="urlId" value="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) % 6 + 1)" />
            <choose>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">
                <set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-australiaeast-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">
                <set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-canadaeast-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">
                <set-variable name="backendUrl" value="{{aoai-eastus-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-eastus-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">
                <set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-francecentral-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">
                <set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-swedencentral-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">
                <set-variable name="backendUrl" value="{{aoai-switzerlandnorth-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-switzerlandnorth-key}}</value>
                </set-header>
              </when>
            </choose>
          </retry>
        </fragment>
        XML
    }
  })
  depends_on = [
    azurerm_api_management_named_value.values,
    azurerm_api_management_named_value.secrets
  ]
  lifecycle {
    ignore_changes = [body]
  }
}

resource "azapi_resource" "gpt_4_retry" {
  type                      = "Microsoft.ApiManagement/service/policyFragments@2023-05-01-preview"
  name                      = "Gpt4Retry"
  parent_id                 = var.apim_id
  schema_validation_enabled = false
  body = jsonencode({
    properties = {
      description = "Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-4 deployment-id"
      format      = "xml"
      value       = <<XML
        <!--
            IMPORTANT:
            - Policy fragment are included as-is whenever they are referenced.
            - If using variables. Ensure they are setup before use.
            - Copy and paste your code here or simply start coding
            Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-4 deployment-id
        -->
        <fragment>
          <retry condition="@(context.Response.StatusCode == 429 &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-4&quot;))" count="12" interval="10" delta="5" first-fast-retry="true">
            <set-variable name="urlId" value="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) % 6 + 1)" />
            <choose>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">
                <set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-australiaeast-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">
                <set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-canadaeast-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">
                <set-variable name="backendUrl" value="{{aoai-eastus-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-eastus-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">
                <set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-francecentral-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">
                <set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-swedencentral-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">
                <set-variable name="backendUrl" value="{{aoai-switzerlandnorth-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-switzerlandnorth-key}}</value>
                </set-header>
              </when>
            </choose>
          </retry>
        </fragment>
        XML
    }
  })
  depends_on = [
    azurerm_api_management_named_value.values,
    azurerm_api_management_named_value.secrets
  ]
  lifecycle {
    ignore_changes = [body]
  }
}

resource "azapi_resource" "gpt_4_turbo_retry" {
  type                      = "Microsoft.ApiManagement/service/policyFragments@2023-05-01-preview"
  name                      = "Gpt4TurboRetry"
  parent_id                 = var.apim_id
  schema_validation_enabled = false
  body = jsonencode({
    properties = {
      description = "Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-4-turbo deployment-id"
      format      = "xml"
      value       = <<XML
        <!--
            IMPORTANT:
            - Policy fragment are included as-is whenever they are referenced.
            - If using variables. Ensure they are setup before use.
            - Copy and paste your code here or simply start coding
            Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-4-turbo deployment-id
        -->
        <fragment>
          <retry condition="@(context.Response.StatusCode == 429 &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-4-turbo&quot;))" count="18" interval="4" delta="2" first-fast-retry="true">
            <set-variable name="urlId" value="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) % 9 + 1)" />
            <choose>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">
                <set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-australiaeast-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">
                <set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-canadaeast-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">
                <set-variable name="backendUrl" value="{{aoai-eastus2-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-eastus2-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">
                <set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-francecentral-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">
                <set-variable name="backendUrl" value="{{aoai-norwayeast-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-norwayeast-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">
                <set-variable name="backendUrl" value="{{aoai-southindia-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-southindia-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 7)">
                <set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-swedencentral-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 8)">
                <set-variable name="backendUrl" value="{{aoai-uksouth-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-uksouth-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 9)">
                <set-variable name="backendUrl" value="{{aoai-westus-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-westus-key}}</value>
                </set-header>
              </when>
            </choose>
          </retry>
        </fragment>
        XML
    }
  })
  depends_on = [
    azurerm_api_management_named_value.values,
    azurerm_api_management_named_value.secrets
  ]
  lifecycle {
    ignore_changes = [body]
  }
}

resource "azapi_resource" "gpt_4_v_retry" {
  type                      = "Microsoft.ApiManagement/service/policyFragments@2023-05-01-preview"
  name                      = "Gpt4vRetry"
  parent_id                 = var.apim_id
  schema_validation_enabled = false
  body = jsonencode({
    properties = {
      description = "Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-4v deployment-id"
      format      = "xml"
      value       = <<XML
        <!--
            IMPORTANT:
            - Policy fragment are included as-is whenever they are referenced.
            - If using variables. Ensure they are setup before use.
            - Copy and paste your code here or simply start coding
            Governs the retry policy and backendUrl resets when a 429 occurs for the gpt-4v deployment-id
        -->
        <fragment>
          <retry condition="@(context.Response.StatusCode == 429 &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-4v&quot;))" count="8" interval="15" delta="5" first-fast-retry="true">
            <set-variable name="urlId" value="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) % 4 + 1)" />
            <choose>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">
                <set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-australiaeast-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">
                <set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-swedencentral-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">
                <set-variable name="backendUrl" value="{{aoai-switzerlandnorth-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-switzerlandnorth-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">
                <set-variable name="backendUrl" value="{{aoai-westus-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-westus-key}}</value>
                </set-header>
              </when>
            </choose>
          </retry>
        </fragment>
        XML
    }
  })
  depends_on = [
    azurerm_api_management_named_value.values,
    azurerm_api_management_named_value.secrets
  ]
  lifecycle {
    ignore_changes = [body]
  }
}

resource "azapi_resource" "set_initial_backend_service" {
  type                      = "Microsoft.ApiManagement/service/policyFragments@2023-05-01-preview"
  name                      = "SetInitialBackendService"
  parent_id                 = var.apim_id
  schema_validation_enabled = false
  body = jsonencode({
    properties = {
      description = "Evaluates the \"aoaiModelName\" variable and then the \"urldId\" variable to determine which backend service to utilize. Then it sets the appropriate \"backendUrl\" and api-key based on the Named values for the service"
      format      = "xml"
      value       = <<XML
        <!--
            IMPORTANT:
            - Policy fragment are included as-is whenever they are referenced.
            - If using variables. Ensure they are setup before use.
            - Copy and paste your code here or simply start coding

            Evaluates the \"aoaiModelName\" variable and then the \"urldId\" variable to determine which backend service to utilize. Then it sets the appropriate \"backendUrl\" and api-key based on the Named values for the service
        -->
        <fragment>
          <choose>
            <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-0301&quot;)">
              <choose>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">
                  <set-variable name="backendUrl" value="{{aoai-westeurope-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-westeurope-key}}</value>
                  </set-header>
                </when>
              </choose>
            </when>
            <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-0613&quot;)">
              <choose>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">
                  <set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-australiaeast-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">
                  <set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-canadaeast-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">
                  <set-variable name="backendUrl" value="{{aoai-eastus-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-eastus-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">
                  <set-variable name="backendUrl" value="{{aoai-eastus2-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-eastus2-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">
                  <set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-francecentral-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">
                  <set-variable name="backendUrl" value="{{aoai-japaneast-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-japaneast-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 7)">
                  <set-variable name="backendUrl" value="{{aoai-northcentral-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-northcentral-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 8)">
                  <set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-swedencentral-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 9)">
                  <set-variable name="backendUrl" value="{{aoai-switzerlandnorth-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-switzerlandnorth-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 10)">
                  <set-variable name="backendUrl" value="{{aoai-uksouth-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-uksouth-key}}</value>
                  </set-header>
                </when>
              </choose>
            </when>
            <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-1106&quot;)">
              <choose>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">
                  <set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-australiaeast-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">
                  <set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-canadaeast-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">
                  <set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-francecentral-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">
                  <set-variable name="backendUrl" value="{{aoai-southindia-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-southindia-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">
                  <set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-swedencentral-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">
                  <set-variable name="backendUrl" value="{{aoai-uksouth-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-uksouth-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 7)">
                  <set-variable name="backendUrl" value="{{aoai-westus-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-westus-key}}</value>
                  </set-header>
                </when>
              </choose>
            </when>
            <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-16k&quot;)">
              <choose>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">
                  <set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-australiaeast-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">
                  <set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-canadaeast-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">
                  <set-variable name="backendUrl" value="{{aoai-eastus-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-eastus-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">
                  <set-variable name="backendUrl" value="{{aoai-eastus2-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-eastus2-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">
                  <set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-francecentral-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">
                  <set-variable name="backendUrl" value="{{aoai-japaneast-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-japaneast-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 7)">
                  <set-variable name="backendUrl" value="{{aoai-northcentral-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-northcentral-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 8)">
                  <set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-swedencentral-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 9)">
                  <set-variable name="backendUrl" value="{{aoai-switzerlandnorth-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-switzerlandnorth-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 10)">
                  <set-variable name="backendUrl" value="{{aoai-uksouth-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-uksouth-key}}</value>
                  </set-header>
                </when>
              </choose>
            </when>
            <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-instruct&quot;)">
              <choose>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">
                  <set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-australiaeast-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">
                  <set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-swedencentral-key}}</value>
                  </set-header>
                </when>
              </choose>
            </when>
            <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-4&quot;)">
              <choose>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">
                  <set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-australiaeast-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">
                  <set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-canadaeast-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">
                  <set-variable name="backendUrl" value="{{aoai-eastus-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-eastus-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">
                  <set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-francecentral-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">
                  <set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-swedencentral-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">
                  <set-variable name="backendUrl" value="{{aoai-switzerlandnorth-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-switzerlandnorth-key}}</value>
                  </set-header>
                </when>
              </choose>
            </when>
            <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-4-32k&quot;)">
              <choose>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">
                  <set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-australiaeast-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">
                  <set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-canadaeast-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">
                  <set-variable name="backendUrl" value="{{aoai-eastus-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-eastus-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">
                  <set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-francecentral-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">
                  <set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-swedencentral-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">
                  <set-variable name="backendUrl" value="{{aoai-switzerlandnorth-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-switzerlandnorth-key}}</value>
                  </set-header>
                </when>
              </choose>
            </when>
            <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-4-turbo&quot;)">
              <choose>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">
                  <set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-australiaeast-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">
                  <set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-canadaeast-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">
                  <set-variable name="backendUrl" value="{{aoai-eastus2-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-eastus2-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">
                  <set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-francecentral-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">
                  <set-variable name="backendUrl" value="{{aoai-norwayeast-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-norwayeast-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">
                  <set-variable name="backendUrl" value="{{aoai-southindia-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-southindia-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 7)">
                  <set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-swedencentral-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 8)">
                  <set-variable name="backendUrl" value="{{aoai-uksouth-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-uksouth-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 9)">
                  <set-variable name="backendUrl" value="{{aoai-westus-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-westus-key}}</value>
                  </set-header>
                </when>
              </choose>
            </when>
            <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-4v&quot;)">
              <choose>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">
                  <set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-australiaeast-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">
                  <set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-swedencentral-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">
                  <set-variable name="backendUrl" value="{{aoai-switzerlandnorth-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-switzerlandnorth-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">
                  <set-variable name="backendUrl" value="{{aoai-westus-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-westus-key}}</value>
                  </set-header>
                </when>
              </choose>
            </when>
            <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;text-embedding-ada-002&quot;)">
              <choose>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">
                  <set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-australiaeast-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">
                  <set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-canadaeast-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">
                  <set-variable name="backendUrl" value="{{aoai-eastus-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-eastus-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">
                  <set-variable name="backendUrl" value="{{aoai-eastus2-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-eastus2-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">
                  <set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-francecentral-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">
                  <set-variable name="backendUrl" value="{{aoai-japaneast-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-japaneast-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 7)">
                  <set-variable name="backendUrl" value="{{aoai-northcentral-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-northcentral-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 8)">
                  <set-variable name="backendUrl" value="{{aoai-norwayeast-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-norwayeast-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 9)">
                  <set-variable name="backendUrl" value="{{aoai-southindia-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-southindia-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 10)">
                  <set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-swedencentral-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 11)">
                  <set-variable name="backendUrl" value="{{aoai-switzerlandnorth-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-switzerlandnorth-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 12)">
                  <set-variable name="backendUrl" value="{{aoai-uksouth-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-uksouth-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 13)">
                  <set-variable name="backendUrl" value="{{aoai-westeurope-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-westeurope-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 14)">
                  <set-variable name="backendUrl" value="{{aoai-westus-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-westus-key}}</value>
                  </set-header>
                </when>
              </choose>
            </when>
            <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;dall-e-3&quot;)">
              <choose>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">
                  <set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-swedencentral-key}}</value>
                  </set-header>
                </when>
              </choose>
            </when>
            <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;whisper&quot;)">
              <choose>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">
                  <set-variable name="backendUrl" value="{{aoai-northcentral-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-northcentral-key}}</value>
                  </set-header>
                </when>
                <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">
                  <set-variable name="backendUrl" value="{{aoai-westeurope-endpoint}}" />
                  <set-header name="api-key" exists-action="override">
                    <value>{{aoai-westeurope-key}}</value>
                  </set-header>
                </when>
              </choose>
            </when>
            <otherwise>
              <set-variable name="backendUrl" value="{{aoai-eastus-endpoint}}" />
              <set-header name="api-key" exists-action="override">
                <value>{{aoai-eastus-key}}</value>
              </set-header>
            </otherwise>
          </choose>
          <set-backend-service base-url="@((string)context.Variables[&quot;backendUrl&quot;])" />
        </fragment>
        XML
    }
  })
  depends_on = [
    azurerm_api_management_named_value.values,
    azurerm_api_management_named_value.secrets
  ]
  lifecycle {
    ignore_changes = [body]
  }
}

resource "azapi_resource" "set_url_id_variable" {
  type                      = "Microsoft.ApiManagement/service/policyFragments@2023-05-01-preview"
  name                      = "SetUrldIdVariable"
  parent_id                 = var.apim_id
  schema_validation_enabled = false
  body = jsonencode({
    properties = {
      description = "Sets the urlId variable, which is a randomly generated number based on the total number of endpoints being used to support an Azure OpenAI model."
      format      = "xml"
      value       = <<XML
        <!--
            IMPORTANT:
            - Policy fragment are included as-is whenever they are referenced.
            - If using variables. Ensure they are setup before use.
            - Copy and paste your code here or simply start coding
        -->
        <fragment>
          <choose>
            <!-- Sets the "urlId" variable to a random number generated via this function:
                value="@(new Random(context.RequestId.GetHashCode()).Next(1, 2))"
                as of Dec 14 2023
                NOTE: 
                        * When using this function the "@(context.Request.MatchedParameters["deployment-id"])" extracts
                        what is then evaluated against the variable "aoaiModelName".
                        * the values in .Next() are inclusive of the minimum and exlusive of the maximum
                        i.e. .Next(1, 2) implies 1 endpoint and .Next(1, 15) implies 14 endpoints
                The "urlId" variable is used in the retry policy as well
                -->
            <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-0301&quot;)">
              <set-variable name="urlId" value="@(new Random(context.RequestId.GetHashCode()).Next(1, 2))" />
            </when>
            <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-0613&quot;)">
              <set-variable name="urlId" value="@(new Random(context.RequestId.GetHashCode()).Next(1, 11))" />
            </when>
            <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-1106&quot;)">
              <set-variable name="urlId" value="@(new Random(context.RequestId.GetHashCode()).Next(1, 8))" />
            </when>
            <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-16k&quot;)">
              <set-variable name="urlId" value="@(new Random(context.RequestId.GetHashCode()).Next(1, 11))" />
            </when>
            <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-35-turbo-instruct&quot;)">
              <set-variable name="urlId" value="@(new Random(context.RequestId.GetHashCode()).Next(1, 3))" />
            </when>
            <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-4&quot;)">
              <set-variable name="urlId" value="@(new Random(context.RequestId.GetHashCode()).Next(1, 7))" />
            </when>
            <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-4-32k&quot;)">
              <set-variable name="urlId" value="@(new Random(context.RequestId.GetHashCode()).Next(1, 7))" />
            </when>
            <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-4-turbo&quot;)">
              <set-variable name="urlId" value="@(new Random(context.RequestId.GetHashCode()).Next(1, 10))" />
            </when>
            <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;gpt-4v&quot;)">
              <set-variable name="urlId" value="@(new Random(context.RequestId.GetHashCode()).Next(1, 5))" />
            </when>
            <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;text-embedding-ada-002&quot;)">
              <set-variable name="urlId" value="@(new Random(context.RequestId.GetHashCode()).Next(1, 15))" />
            </when>
            <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;dall-e-3&quot;)">
              <set-variable name="urlId" value="@(new Random(context.RequestId.GetHashCode()).Next(1, 2))" />
            </when>
            <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;whisper&quot;)">
              <set-variable name="urlId" value="@(new Random(context.RequestId.GetHashCode()).Next(1, 3))" />
            </when>
          </choose>
        </fragment>
        XML
    }
  })
  depends_on = [
    azurerm_api_management_named_value.values,
    azurerm_api_management_named_value.secrets
  ]
  lifecycle {
    ignore_changes = [body]
  }
}

resource "azapi_resource" "text_embedding_ada_002_retry" {
  type                      = "Microsoft.ApiManagement/service/policyFragments@2023-05-01-preview"
  name                      = "TextEmbeddingAda002Retry"
  parent_id                 = var.apim_id
  schema_validation_enabled = false
  body = jsonencode({
    properties = {
      description = "Governs the retry policy and backendUrl resets when a 429 occurs for the text-embedding-ada-002 deployment-id"
      format      = "xml"
      value       = <<XML
        <!--
            IMPORTANT:
            - Policy fragment are included as-is whenever they are referenced.
            - If using variables. Ensure they are setup before use.
            - Copy and paste your code here or simply start coding
            Governs the retry policy and backendUrl resets when a 429 occurs for the text-embedding-ada-002 deployment-id
        -->
        <fragment>
          <retry condition="@(context.Response.StatusCode == 429 &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;text-embedding-ada-002&quot;))" count="28" interval="4" delta="2" first-fast-retry="true">
            <set-variable name="urlId" value="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) % 14 + 1)" />
            <choose>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">
                <set-variable name="backendUrl" value="{{aoai-australiaeast-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-australiaeast-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">
                <set-variable name="backendUrl" value="{{aoai-canadaeast-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-canadaeast-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 3)">
                <set-variable name="backendUrl" value="{{aoai-eastus-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-eastus-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 4)">
                <set-variable name="backendUrl" value="{{aoai-eastus2-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-eastus2-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 5)">
                <set-variable name="backendUrl" value="{{aoai-francecentral-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-francecentral-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 6)">
                <set-variable name="backendUrl" value="{{aoai-japaneast-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-japaneast-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 7)">
                <set-variable name="backendUrl" value="{{aoai-northcentral-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-northcentral-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 8)">
                <set-variable name="backendUrl" value="{{aoai-norwayeast-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-norwayeast-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 9)">
                <set-variable name="backendUrl" value="{{aoai-southindia-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-southindia-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 10)">
                <set-variable name="backendUrl" value="{{aoai-swedencentral-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-swedencentral-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 11)">
                <set-variable name="backendUrl" value="{{aoai-switzerlandnorth-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-switzerlandnorth-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 12)">
                <set-variable name="backendUrl" value="{{aoai-uksouth-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-uksouth-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 13)">
                <set-variable name="backendUrl" value="{{aoai-westeurope-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-westeurope-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 14)">
                <set-variable name="backendUrl" value="{{aoai-westus-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-westus-key}}</value>
                </set-header>
              </when>
            </choose>
          </retry>
        </fragment>
        XML
    }
  })
  depends_on = [
    azurerm_api_management_named_value.values,
    azurerm_api_management_named_value.secrets
  ]
  lifecycle {
    ignore_changes = [body]
  }
}

resource "azapi_resource" "whisper_retry" {
  type                      = "Microsoft.ApiManagement/service/policyFragments@2023-05-01-preview"
  name                      = "WhisperRetry"
  parent_id                 = var.apim_id
  schema_validation_enabled = false
  body = jsonencode({
    properties = {
      description = "Governs the retry policy and backendUrl resets when a 429 occurs for the whisper deployment-id"
      format      = "xml"
      value       = <<XML
        <!--
            IMPORTANT:
            - Policy fragment are included as-is whenever they are referenced.
            - If using variables. Ensure they are setup before use.
            - Copy and paste your code here or simply start coding
            Governs the retry policy and backendUrl resets when a 429 occurs for the whisper deployment-id
        -->
        <fragment>
          <retry condition="@(context.Response.StatusCode == 429 &amp;&amp; (context.Variables.GetValueOrDefault&lt;string&gt;(&quot;aoaiModelName&quot;) == &quot;whisper&quot;))" count="4" interval="15" delta="5" first-fast-retry="true">
            <set-variable name="urlId" value="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) % 2 + 1)" />
            <choose>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 1)">
                <set-variable name="backendUrl" value="{{aoai-northcentral-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-northcentral-key}}</value>
                </set-header>
              </when>
              <when condition="@(context.Variables.GetValueOrDefault&lt;int&gt;(&quot;urlId&quot;) == 2)">
                <set-variable name="backendUrl" value="{{aoai-westeurope-endpoint}}" />
                <set-header name="api-key" exists-action="override">
                  <value>{{aoai-westeurope-key}}</value>
                </set-header>
              </when>
            </choose>
          </retry>
        </fragment>
        XML
    }
  })
  depends_on = [
    azurerm_api_management_named_value.values,
    azurerm_api_management_named_value.secrets
  ]
  lifecycle {
    ignore_changes = [body]
  }
}
