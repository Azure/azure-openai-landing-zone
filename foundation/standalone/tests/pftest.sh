#!/bin/bash

print_status() {
    echo -e "\e[32m$1\e[0m"
}

print_warning() {
    echo -e "\e[33m$1\e[0m"
}

RESOURCE_GROUP_NAME=$1

CONDA_ENV_NAME="aoai-landingzone"
source ~/miniconda3/etc/profile.d/conda.sh
conda activate $CONDA_ENV_NAME


while [ -z "${RESOURCE_GROUP_NAME}" ]
do
    print_warning "Please provide resource group name:"
    read RESOURCE_GROUP_NAME
done

RG_EXISTS=$(az group exists -g $RESOURCE_GROUP_NAME | jq -r '.') 

if [ $RG_EXISTS = "false" ]
then
    print_warning "Resource group $RESOURCE_GROUP_NAME does not exist. Please run create_ai_studio.sh script first."
    exit 1
fi

ai_service_name=$(az resource list -g $RESOURCE_GROUP_NAME --query "[?type=='Microsoft.CognitiveServices/accounts']" | jq -r .[].name)
ai_service_key=$(az cognitiveservices account keys list -g $RESOURCE_GROUP_NAME -n $ai_service_name | jq -r .key1)
api_base=$(az cognitiveservices account show --name $ai_service_name -g $RESOURCE_GROUP_NAME | jq -r '.properties.endpoints["OpenAI Language Model Instance API"]')
ai_service_deployment_name=$(az cognitiveservices account deployment list --name $ai_service_name -g $RESOURCE_GROUP_NAME | jq -r .[0].name)


sed -i "/deployment_name:/s|.*|    deployment_name: $ai_service_deployment_name |" ./pftest_chatbot/flow.dag.yaml


pf connection create --file ./pftest_chatbot/azure_openai.yaml --set api_key=$ai_service_key api_base=$api_base --name open_ai_connection
pf flow test --flow ./pftest_chatbot --interactive


conda deactivate