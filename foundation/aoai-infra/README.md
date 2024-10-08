# Azure OpenAI Bicep Deployment

This guide provides step-by-step instructions for deploying Azure OpenAI services using Bicep templates. Before proceeding, ensure you meet all the prerequisites listed below.
This deploys Azure OpenAI resource to Virtual Network with Private Endpoints and configures Role Based access control.

## Prerequisites

To deploy Azure OpenAI using Bicep, you need to have the following:

- **Existing Resource Group**: Ensure you have an existing resource group with contributor permissions.
- **Azure OpenAI Enabled**: Azure OpenAI service must be enabled on your Azure subscription.
- **Existing Virtual Network (VNet)**: A VNet should be pre-provisioned with permissions to deploy a Private Endpoint in a subnet.
- **Existing Private DNS Zone**: You should have a private DNS zone for `privatelink.openai.azure.com`.
- **Resource Group Names**: Know the resource group names for your VNet and private DNS zones.
- **Azure CLI**: The Azure Command Line Interface (CLI) should be installed on your system.
- **PowerShell or Bash**: Ensure you have PowerShell (for Windows) or Bash (for Linux/Mac) installed.
- **Azure Portal Login**: Make sure you are logged into the Azure Portal using the Azure CLI.
- **Usernames**: Prepare a list of usernames (in the format `username@domain.com`) that need to be provisioned.

## Deployment Steps

### Azure Login Steps

Follow these steps to log into your Azure account using the Azure CLI.

1. **Login to Azure**: Use the Azure CLI to log into your Azure account.

    Copy and paste the following command into your terminal or command prompt:
    ```
    az login
    ```

2. **Set Your Azure Subscription**:

    Replace `<your-subscription-id>` with your actual Azure subscription ID:
    ```
    az account set --subscription "<your-subscription-id>"
    ```

3. **Deploy to Azure Resource Group**:

    Replace `<existing-resource-group>` with your existing Azure resource group:
    ```
    az deployment group create --resource-group "<existing-resource-group>" --template-file .\main.bicep --parameters .\main.bicepparam

4. **Test Azure OpenAI Endpoint**:

   - For Bash:
     ```bash
     ./test.sh
     ```

   - For PowerShell:
     ```powershell
     .\test.ps1
     ```


 az network private-endpoint show --name azure-ai-7uj23hng7h22c-westus-pe --resource-group test-azure-ai-rg --query 'networkInterfaces[*].id' --output table

 az network nic show --ids /subscriptions/f1a8fafd-a8a3-46d8-bb5e-01deb63d275d/resourceGroups/test-azure-ai-rg/providers/Microsoft.Network/networkInterfaces/azure-ai-7uj23hng7h22c-westus-pe.nic.e4f1eb0b-c539-4fef-96b0-1291e56ab5e1 --query 'ipConfigurations[*].{IPAddress: privateIPAddress, FQDNs: privateLinkConnectionProperties.fqdns}'


 [
  {
    "FQDNs": [
      "60ae06e1-d146-4d1b-8e3b-b6a9590afae2.workspace.westus.api.azureml.ms",
      "60ae06e1-d146-4d1b-8e3b-b6a9590afae2.workspace.westus.cert.api.azureml.ms"
    ],
    "IPAddress": "10.0.2.105"
  },
  {
    "FQDNs": [
      "ml-azure-ai-7uj23hn-westus-60ae06e1-d146-4d1b-8e3b-b6a9590afae2.westus.notebooks.azure.net"
    ],
    "IPAddress": "10.0.2.106"
  },
  {
    "FQDNs": [
      "*.60ae06e1-d146-4d1b-8e3b-b6a9590afae2.inference.westus.api.azureml.ms"
    ],
    "IPAddress": "10.0.2.107"
  }
]