#!/bin/bash

# check if conda is installed

print_status() {
    echo -e "\e[32m$1\e[0m"
}


RESOURCE_GROUP_NAME=$1

CONDA_ENV_NAME="aoai-landingzone"

if [ -x "$(command -v conda)" ]; then
    print_status "conda is installed"
    
    # check if conda environment exists
    if conda env list | grep -q "$CONDA_ENV_NAME"; then
        print_status "$CONDA_ENV_NAME environment exists"        
    else
        print_status "$CONDA_ENV_NAME environment does not exist"
        conda create -n $CONDA_ENV_NAME python=3.10 -y
    fi    
else
    print_status "conda is not installed"
    print_status "Installing conda"
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
    chmod +x ./Miniconda3-latest-Linux-x86_64.sh
    ./Miniconda3-latest-Linux-x86_64.sh -b -p $HOME/miniconda
    export PATH="$HOME/miniconda/bin:$PATH"
    conda init bash
    source ~/.bashrc
    conda init
    conda config --set auto_activate_base false
    conda config --set always_yes yes
    conda update -n base -c defaults conda
    conda create -n $CONDA_ENV_NAME python=3.10
fi

subscription_id=$(az account show | jq -r .id)
ai_resource_name=$(az resource list -g $RESOURCE_GROUP_NAME --query "[?kind=='Hub']" | jq -r .[0].name)
search_service_name=$(az resource list -g $RESOURCE_GROUP_NAME --query "[?type=='Microsoft.Search/searchServices']" | jq -r .[].name)
aisearch_api_key=$(az search admin-key show -g $RESOURCE_GROUP_NAME --service-name $search_service_name  | jq -r .primaryKey)
ai_search_connection_name="${search_service_name}_connection_$(uuidgen)"

source ~/miniconda3/etc/profile.d/conda.sh

# Activate the specific Conda environment
conda activate $CONDA_ENV_NAME

print_status "installing python dependencies..."    
pip install -r requirements.txt

print_status "creating connection in AI Studio..."  
python ./aistudio_create_connections.py --subscription_id $subscription_id --resource_group_name $RESOURCE_GROUP_NAME  --ai_resource_name $ai_resource_name --connection_name $ai_search_connection_name --ai_search_name "$search_service_name" --ai_search_key "$aisearch_api_key"

# Deactivate Conda environment
conda deactivate