# This test is using v1.x of the Azure OpenAI Python SDK
# https://learn.microsoft.com/en-us/azure/ai-services/openai/how-to/migration?tabs=python-new%2Cdalle-fix#chat-completions
from openai import AzureOpenAI

# Define the AzureOpenAI client object
client = AzureOpenAI(
  azure_endpoint="https://{your_apim_resource_name}.azure-api.net/",
  api_key="{your_apim_subscription_key}",
  api_version="2023-12-01-preview"
)

# Define the system role message to define our quick test assistant
system_role_message = {
  "role": "system",
  "content": "You are an AI assistant that helps people find information."
}

# Define the user role messages to pass to our quick assistant
user_message_esg = {
  "role": "user",
  "content": "Tell me a joke about Azure API Management."
}

# Prepare to laugh
response_esg = client.chat.completions.create(
    model="gpt-4-turbo",
    messages=[
        system_role_message,
        user_message_esg
    ],
    stream=False,
)
assistant_response_esg=response_esg.choices[0].message.content
print("GPT-4-Turbo's joke: " + "\n" + "\n" + assistant_response_esg)