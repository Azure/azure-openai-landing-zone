#!/bin/bash


aoaiServiceName=$1
if [ -z "${aoaiServiceName}" ]; then
    echo "Existing Azure OpenAI Resource Name:"
    read aoaiServiceName
fi


deploymentName=$2
if [ -z "${deploymentName}" ]; then
    echo "Azure OpenAI Model Deployment Name:"
    read deploymentName
fi

#az ad user show --id pbiuser@anildwa1.onmicrosoft.com
resource="https://cognitiveservices.azure.com/"
tenantId=$(az account show | jq -r .tenantId)
accessToken=$(az account get-access-token --resource $resource --tenant $tenantId | jq -r .accessToken)

curl https://$aoaiServiceName.openai.azure.com/openai/deployments/$deploymentName/chat/completions?api-version=2023-05-15\
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $accessToken" \
  -H "api-type: azure_ad" \
  -d '{"max_tokens": 70, "messages":[{"role": "system", "content": "You are a helpful assistant. Generate full sentence."},{"role": "user", "content": "Tell me something about Azure OpenAI"}]}'
