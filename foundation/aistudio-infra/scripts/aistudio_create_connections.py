import argparse
from azure.ai.resources.client import AIClient
from azure.identity import DefaultAzureCredential
from azure.ai.resources.entities import AzureAISearchConnection
from azure.ai.ml.entities._credentials import ApiKeyConfiguration

def create_ai_search_connection(subscription_id:str, resource_group_name: str, connection_name: str, ai_resource_name: str, ai_search_name: str, ai_search_key: str):
    ai_client = AIClient(credential=DefaultAzureCredential(), subscription_id=subscription_id,
                     resource_group_name=resource_group_name, ai_resource_name=ai_resource_name)
    _connection_name = connection_name
    cred = ApiKeyConfiguration(key=ai_search_key)
    target = f"https://{ai_search_name}.search.windows.net"
    local_conn = AzureAISearchConnection(name="overwrite", credentials=None, target="overwrite")
    local_conn.name = _connection_name
    local_conn.credentials = cred
    local_conn.target = target
    ai_client.connections.create_or_update(local_conn)
    result_connection_name = ai_client.connections.get(_connection_name)
    if result_connection_name.name == _connection_name:
        print(f"{connection_name} Connection created successfully.")
        return(f"{connection_name} Connection created successfully.")

def main(args):
    return create_ai_search_connection(args.subscription_id, args.resource_group_name,args.connection_name, args.ai_resource_name,  args.ai_search_name, args.ai_search_key)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Create Azure AI Studio Connections")
    parser.add_argument("--subscription_id", type=str, help="Azure Subscription ID")    
    parser.add_argument("--resource_group_name", type=str, help="Azure Resource Group Name") 
    parser.add_argument("--ai_resource_name", type=str, help="AI Resource Name")    
    parser.add_argument("--connection_name", type=str, help="AI Search Connection Name")    
    parser.add_argument("--ai_search_name", type=str, help="AI Search Service Name") 
    parser.add_argument("--ai_search_key", type=str, help="AI Search Service Admin Key")    
    args = parser.parse_args()
    main(args)
    