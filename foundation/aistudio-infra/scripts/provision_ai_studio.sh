#!/bin/bash


print_status() {
    echo -e "\e[32m$1\e[0m"
}

print_warning() {
    echo -e "\e[33m$1\e[0m"
}

RESOURCE_GROUP_NAME=$1
LOCATION=$2
NEW_AI_RESOURCE=$3
CREATE_PROJECT=$4

while [ -z "${RESOURCE_GROUP_NAME}" ]
do
    print_warning "Please provide resource group name:"
    read RESOURCE_GROUP_NAME
done

while [ -z "${LOCATION}" ]
do
    print_warning "Please provide location. For e.g westus, eastus2, northcentralus:"
    read LOCATION
done


while [ -z "${NEW_AI_RESOURCE}" ] || { [ "${NEW_AI_RESOURCE}" != true ] && [ "${NEW_AI_RESOURCE}" != false ]; }
do
    print_warning "Create new AI Resource? (y/n):"
    read NEW_AI_RESOURCE

    if [ "$NEW_AI_RESOURCE" == "y" ]; then
        NEW_AI_RESOURCE=true
    elif [ "$NEW_AI_RESOURCE" == "n" ]; then
        NEW_AI_RESOURCE=false
    else
        print_warning "Please enter y or n"
        NEW_AI_RESOURCE=""
    fi
done


while [ -z "${CREATE_PROJECT}" ] || { [ "${CREATE_PROJECT}" != true ] && [ "${CREATE_PROJECT}" != false ]; }
do
    print_warning "Create new AI project? (y/n):"
    read CREATE_PROJECT

    if [ "$CREATE_PROJECT" == "y" ]; then
        CREATE_PROJECT=true
    elif [ "$CREATE_PROJECT" == "n" ]; then
        CREATE_PROJECT=false
    else
        print_warning "Please enter y or n"
        CREATE_PROJECT=""
    fi
done

RG_EXISTS=$(az group exists -g $RESOURCE_GROUP_NAME | jq -r '.') 

if [ $RG_EXISTS = "false" ]
then
    print_status "Creating resource group $RESOURCE_GROUP_NAME in $LOCATION"
    az group create -g $RESOURCE_GROUP_NAME -l $LOCATION
fi

if [ $NEW_AI_RESOURCE == true ]; then
    print_status "Creating Azure AI resources in resource group $RESOURCE_GROUP_NAME in $LOCATION"
    az deployment group create --resource-group $RESOURCE_GROUP_NAME --template-file ../bicep/azure-ai.bicep --parameters ../bicep/azure-ai-local.bicepparam
    if [ $? -eq 0 ]; then
        print_status "Azure AI resources created successfully in resource group $RESOURCE_GROUP_NAME in $LOCATION"
        print_status "Retreving IP Address and DNS information for resource group $RESOURCE_GROUP_NAME in $LOCATION"
        ./get_ipconfig.sh $RESOURCE_GROUP_NAME $LOCATION 
        print_status "Setting up AI studio connections..."
        ./setup_python_env.sh $RESOURCE_GROUP_NAME $LOCATION 
    fi
fi

if [ $CREATE_PROJECT == true ]; then
    
    print_status "Creating project in resource group $RESOURCE_GROUP_NAME in $LOCATION"
    az deployment group create --resource-group $RESOURCE_GROUP_NAME --template-file ../bicep/azure-ai-project.bicep --parameters ../bicep/azure-ai-project-local.bicepparam
    if [ $? -eq 0 ]; then
        print_status "Azure AI Project created successfully in resource group $RESOURCE_GROUP_NAME in $LOCATION"
        print_status "Retreving IP Address and DNS information for resource group $RESOURCE_GROUP_NAME in $LOCATION"
        ./get_ipconfig.sh $RESOURCE_GROUP_NAME $LOCATION 
    fi
fi


