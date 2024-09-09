#!/bin/bash

RESOURCE_GROUP_NAME=$1
LOCATION=$2

HUB_DNS_NAME="workspace.$LOCATION.api.azureml.ms"
HUB_IP=""

while [ -z "${RESOURCE_GROUP_NAME}" ]
do
    echo "Please provide resource group name:"
    read RESOURCE_GROUP_NAME
done

while [ -z "${LOCATION}" ]
do
    echo "Please provide location. e.g westus, northcentralus:"
    read LOCATION
done

for ai_resource_name in $(az resource list -g $RESOURCE_GROUP_NAME -l $LOCATION --query "[?kind=='Hub']" | jq -r .[].name); do
    ai_hub_pe_name="$ai_resource_name-AIHub-PE"
    echo "Found AI Resource":$ai_resource_name
    
    NIC_RESOURCE_ID=$(az network private-endpoint show --name $ai_hub_pe_name --resource-group $RESOURCE_GROUP_NAME | jq -r .networkInterfaces[0].id)
    #echo "NetworkInterface Resource Id:" $nic_resource_id
    
    az network nic show --ids $NIC_RESOURCE_ID | jq -r '.ipConfigurations[] | .privateIPAddress as $ip | .privateLinkConnectionProperties.fqdns[] | "\($ip) \(.)"'

    #echo "Hub DNS Name:" $HUB_DNS_NAME
    HUB_IP=$(az network nic show --ids $NIC_RESOURCE_ID | jq -r '.ipConfigurations[0] | .privateIPAddress as $ip | "\($ip)"')

    STORAGE_ACCOUNT_NAME=$(az resource list -g $RESOURCE_GROUP_NAME -l $LOCATION --query "[?type=='Microsoft.Storage/storageAccounts']" | jq -r .[].name)
    STORAGE_ACCOUNT_ID=$(az storage account show \
        --name $STORAGE_ACCOUNT_NAME \
        --resource-group $RESOURCE_GROUP_NAME \
        --query "id" -o tsv)
    
    PRIVATE_ENDPOINT_ID=$(az network private-endpoint list \
        --resource-group $RESOURCE_GROUP_NAME \
        --query "[?privateLinkServiceConnections[?privateLinkServiceId=='$STORAGE_ACCOUNT_ID']].id" \
        -o tsv)
    for endpoint_id in $PRIVATE_ENDPOINT_ID; do
        # Retrieve the NIC Resource ID for each private endpoint
        NIC_RESOURCE_ID=$(az network private-endpoint show \
            --ids $endpoint_id \
            --query "networkInterfaces[0].id" \
            -o tsv)
        az network nic show --ids $NIC_RESOURCE_ID | jq -r '.ipConfigurations[] | .privateIPAddress as $ip | .privateLinkConnectionProperties.fqdns[] | "\($ip) \(.)"'
        done   

    AZURE_AI_SERVICES_NAME=$(az resource list -g $RESOURCE_GROUP_NAME -l $LOCATION --query "[?type=='Microsoft.CognitiveServices/accounts']" | jq -r .[].name)
    AZURE_AI_SERVICES_ID=$(az cognitiveservices account show \
        --name $AZURE_AI_SERVICES_NAME \
        --resource-group $RESOURCE_GROUP_NAME \
        --query "id" -o tsv)
    PRIVATE_ENDPOINT_ID=$(az network private-endpoint list \
        --resource-group $RESOURCE_GROUP_NAME \
        --query "[?privateLinkServiceConnections[?privateLinkServiceId=='$AZURE_AI_SERVICES_ID']].id" \
        -o tsv)
    for endpoint_id in $PRIVATE_ENDPOINT_ID; do
        # Retrieve the NIC Resource ID for each private endpoint
        NIC_RESOURCE_ID=$(az network private-endpoint show \
            --ids $endpoint_id \
            --query "networkInterfaces[0].id" \
            -o tsv)
        az network nic show --ids $NIC_RESOURCE_ID | jq -r '.ipConfigurations[] | .privateIPAddress as $ip | .privateLinkConnectionProperties.fqdns[] | "\($ip) \(.)"'
        done 
done

for ai_project_name in $(az resource list -g $RESOURCE_GROUP_NAME -l $LOCATION --query "[?kind=='Project']" | jq -r .[].name); do
    workspaceid=$(az resource show -g $RESOURCE_GROUP_NAME -n $ai_project_name --resource-type Microsoft.MachineLearningServices/workspaces | jq -r '.properties.workspaceId')
    echo "$HUB_IP $workspaceid.$HUB_DNS_NAME"
    echo "$HUB_IP $workspaceid.workspace.$LOCATION.cert.api.azureml.ms"
done

