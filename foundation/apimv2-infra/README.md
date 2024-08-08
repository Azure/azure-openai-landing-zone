# Azure OpenAI API Management v2 Bicep Deployment

## Table of Contents

- [Deployment Description](#deployment-description)
- [Prerequisites](#prerequisites)
- [Resources Deployed](#resources-deployed)
- [Deployment Instructions](deployment-instructions)

## Deployment Description

This repository contains an Azure Bicep deployment for [Azure API Management Service (APIM) v2](https://learn.microsoft.com/en-us/azure/api-management/v2-service-tiers-overview) in order to load balance traffic across multiple Azure OpenAI endpoints. This is accomplished via a series of Policy Snippets and a Policy Definition to handle HTTP 429 Error retry logic. The APIM deployment logs the metrics, prompts, and completions in Application Insights and Azure Monitor as well a logger to send non-streaming and non-embeddings logs to Event Hubs. The [openaAIOpenAPI.json](../apimv2-infra/bicep/artifacts/openAIOpenAPI.json) is a local copy of the Azure ["2023-12-01-preview" Azure OpenAI Inference API Spec](https://github.com/Azure/azure-rest-api-specs/blob/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/preview/2023-12-01-preview/inference.json). This will allow you to make calls with api_version="2023-12-01-preview" set. If you wish to use a different api version, you will need to replace the API Spec with the version you wish to call.
Pay special attention to the model deployment-ids (the name you assigned the model when you deployed it).
The individual Biceps and all the elements within APIM, including the policy fragments and main policy, have in-line comments and documentation to explain the actions taken by each section.
> **NOTE:** The first release of this bicep does not deploy with Private Endpoints as they are not yet supported by APIM v2

## Prerequisites

- An Azure Subscription
- Owner rights to the Azure Subscription
- [Download and Install the Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- This repo assumes you have deployed multiple Azure OpenAI resources and named the model deployments (deployment-id) with this naming convention:
    - whisper
    - gpt-35-turbo-0301
    - gpt-35-turbo-16k
    - gpt-4
    - gpt-4-32k
    - gpt-35-turbo-0613
    - gpt-35-turbo-instruct
    - gpt-35-turbo-1106
    - gpt-4-turbo
    - text-embedding-ada-002
    - dall-e-3
    - gpt-4v
- The endpoint and a key for multiple Azure OpenAI resources

> **Warning:** If you do not use the above naming conventions you will need to adjust the [apimServiceConfiguration.bicep](../apimv2-infra/bicep/modules/apimServiceConfiguration.bicep) to correctly set the aoaiModelName variable to match what you have named your deployments. Search the linked bicep for: ```(&quot;aoaiModelName&quot;) == &quot;gpt-4-turbo&quot;))``` and fill in the correct name for your deployment, for example, ```gpt-4-turbo``` 

## Resources Deployed

- Resource Group
- API Management service
- Application Insights
- Stream Analytics job
- Event Hubs Namespace
- Key vault
- Log Analytics workspace
- Storage account
- Smart detector alert rule

## Deployment Instructions

1. Clone the repo to your local machine (Note the location as you will need it for Steps 3 and 4)

2. [Fill out this file:](https://github.com/Azure/azure-openai-landing-zone/blob/main/foundation/apimv2-infra/bicep/apimv2.bicepparam) Edit the secretValue and endpointURL *ONLY FOR THE REGIONS WHERE YOU HAVE DEPLOYED RESOURCES*. Leave the entry alone if you do not have a resource deployed there.
<img src=./assets/endpoint_and_key_mapping.png>

3. Choose a region in which to deploy your resource group containing the elements listed in [Resources Deployed](#resources-deployed).

4. Run the following code after changing out the {deploymentRegion} to what you chosen in Step 2 above and {localPathToRepo} to point to where you cloned this repository on your local machine. 

    ```azcli
    az deployment sub create --location {deploymentRegion} --template-file '{localPathToRepo}/apimv2.bicep' --parameters '{localPathToRepo}/apimv2.bicepparams'
    ```

5. Once the deployment completes, navigate to your newly created APIM v2 instance and note the URL for your new service and the key value for your Dev or Prod subscription service within APIM:

    **Endpoint:**

    Click on *API* in the API section on the lef-hand side navigation menu. Select the *Azure OpenAI Service API* in the middle menu area and then go into the *Settings*. Copy the *base url*, which will have this format: https://{yourAPIMname}.azure-api.net/openai

    <img src=./assets/apim_endpoint_1.png width=900>

    **Key:**

    Click on the *Subscriptions* section on the left-hand side navigation menu. Then click the 3 dots (...) next to the subscription type you want to use and select *Show/hide keys* and copy the key value you wish to use.

    <img src=./assets/apim_key_1.png width=900>

6. Use either the [endpoint_test.ipynb](../apimv2-infra/endpoint_test.ipynb) or [endpoint_test.py](../apimv2-infra/endpoint_test.py) substituting your API-M endpoint and key for the variable ```azure_endpoint="https://{your_apim_resource_name}.azure-api.net/"``` and ```api_key="{your_apim_subscription_key}"``` to match what you retrieved in Step #5 above. You may also wish to change the model being tested as the supplied scripts use ```model="gpt-4-turbo"```.