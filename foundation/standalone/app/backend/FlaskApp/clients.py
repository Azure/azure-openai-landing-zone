import logging
import os
import random
from typing import List

from openai import AzureOpenAI
from azure.core.credentials import AzureKeyCredential
from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from azure.search.documents import SearchClient
from azure.search.documents.indexes import SearchIndexClient
from azure.storage.blob import BlobServiceClient
from langchain.utilities import BingSearchAPIWrapper

# Environment Variables
USE_MANAGED_IDENTITIES = os.environ.get("USE_MANAGED_IDENTITIES") == "true"
AZURE_FORM_RECOGNIZER_KEY = os.environ.get("AZURE_FORM_RECOGNIZER_KEY") or None
AZURE_FORM_RECOGNIZER_SERVICE = os.environ.get("AZURE_FORM_RECOGNIZER_SERVICE") or "myformrecognizer"
AZURE_OPENAI_CHATGPT_DEPLOYMENT = os.environ.get("AZURE_OPENAI_CHATGPT_DEPLOYMENT") or "gpt-35-turbo"
AZURE_OPENAI_DEFAULT_TEMP = os.environ.get("AZURE_OPENAI_DEFAULT_TEMP") or 0.1
AZURE_OPENAI_GPT_DEPLOYMENT = os.environ.get("AZURE_OPENAI_GPT_DEPLOYMENT") or "text-davinci-003"
AZURE_OPENAI_GPT4_DEPLOYMENT = os.environ.get("AZURE_OPENAI_GPT4_DEPLOYMENT") or "gpt4"
AZURE_OPENAI_GPT4_SERVICE_1 = os.environ.get("AZURE_OPENAI_GPT4_SERVICE_1") or ""
AZURE_OPENAI_GPT4_SERVICE_1_KEY = os.environ.get("AZURE_OPENAI_GPT4_SERVICE_1_KEY") or ""
AZURE_OPENAI_SERVICE_1 = os.environ.get("AZURE_OPENAI_SERVICE_1") or ""
AZURE_OPENAI_SERVICE_1_KEY = os.environ.get("AZURE_OPENAI_SERVICE_1_KEY") or ""
AZURE_OPENAI_SERVICE_2 = os.environ.get("AZURE_OPENAI_SERVICE_2") or ""
AZURE_OPENAI_SERVICE_2_KEY = os.environ.get("AZURE_OPENAI_SERVICE_2_KEY") or ""
AZURE_OPENAI_SERVICE_3 = os.environ.get("AZURE_OPENAI_SERVICE_3") or ""
AZURE_OPENAI_SERVICE_3_KEY = os.environ.get("AZURE_OPENAI_SERVICE_3_KEY") or ""
AZURE_SEARCH_INDEX = os.environ.get("AZURE_SEARCH_INDEX") or "gptkbindex"
AZURE_SEARCH_KEY = os.environ.get("AZURE_SEARCH_KEY") or ""
AZURE_SEARCH_SERVICE = os.environ.get("AZURE_SEARCH_SERVICE") or "gptkb-y2nmeuebipp4i"
AZURE_STORAGE_ACCOUNT = os.environ.get("AZURE_STORAGE_ACCOUNT") or "mystorageaccount"
AZURE_STORAGE_CONTAINER = os.environ.get("AZURE_STORAGE_CONTAINER") or "content"
AZURE_STORAGE_KEY = os.environ.get("AZURE_STORAGE_KEY") or None
AZURE_TENANT_ID = os.environ.get("AZURE_TENANT_ID") or None
BING_SEARCH_URL = os.environ.get("BING_SEARCH_URL") or 'https://api.bing.microsoft.com/v7.0/search'
BING_SUBSCRIPTION_KEY = os.environ.get("BING_SUBSCRIPTION_KEY") or ""
CATEGORY = os.environ.get("CATEGORY") or "default"
KB_FIELDS_CATEGORY = os.environ.get("KB_FIELDS_CATEGORY") or "category"
KB_FIELDS_CONTENT = os.environ.get("KB_FIELDS_CONTENT") or "content"
KB_FIELDS_SOURCEPAGE = os.environ.get("KB_FIELDS_SOURCEPAGE") or "sourcepage"
LOCAL_PDF_PARSER_BOOL = os.environ.get("LOCAL_PDF_PARSER_BOOL") or False
LOG_VERBOSE = os.environ.get("LOG_VERBOSE") or False
MAX_SECTION_LENGTH = 1000
OPENAI_TOKEN = os.environ.get("OPENAI_TOKEN") or ""
SECTION_OVERLAP = 100
SENTENCE_SEARCH_LIMIT = 100
USE_AZURE_OPENAI = os.environ.get("USE_AZURE_OPENAI") or True

api_endpoints = [
    {"base_url": f"https://{AZURE_OPENAI_SERVICE_1}.openai.azure.com", "key": f"{AZURE_OPENAI_SERVICE_1_KEY}"},
    {"base_url": f"https://{AZURE_OPENAI_SERVICE_2}.openai.azure.com", "key": f"{AZURE_OPENAI_SERVICE_2_KEY}"},
    {"base_url": f"https://{AZURE_OPENAI_SERVICE_3}.openai.azure.com", "key": f"{AZURE_OPENAI_SERVICE_3_KEY}"},
]

# Function to get a random endpoint
def get_random_endpoint():
    return random.choice(api_endpoints)

# Set up managed identity or key-based credentials
azure_credential = DefaultAzureCredential()

def get_search_client():
    return SearchClient(
        endpoint=f"https://{AZURE_SEARCH_SERVICE}.search.windows.net",
        index_name=AZURE_SEARCH_INDEX,
        credential=azure_credential if USE_MANAGED_IDENTITIES else AzureKeyCredential(AZURE_SEARCH_KEY))

def get_blob_client():
    return BlobServiceClient(
        account_url=f"https://{AZURE_STORAGE_ACCOUNT}.blob.core.windows.net",
        credential=azure_credential if USE_MANAGED_IDENTITIES else AzureKeyCredential(AZURE_STORAGE_KEY))

def get_form_recognizer_creds():
    return azure_credential if USE_MANAGED_IDENTITIES else AzureKeyCredential(AZURE_FORM_RECOGNIZER_KEY)

def get_openai_client(endpoint):
    if USE_MANAGED_IDENTITIES:
        token_provider = get_bearer_token_provider(
            azure_credential, "https://cognitiveservices.azure.com/.default"
        )
        return AzureOpenAI(
            azure_endpoint=endpoint,
            azure_ad_token_provider=token_provider,
            api_version="2023-12-01-preview"
        )
    else:
        return AzureOpenAI(
            azure_endpoint=endpoint,
            azure_api_key=OPENAI_TOKEN,
            api_version="2023-12-01-preview"
        )

# Create clients
search_client = get_search_client()
blob_client = get_blob_client()
formrecognizer_creds = get_form_recognizer_creds()
endpoint = get_random_endpoint()['base_url']
azure_openai_client = get_openai_client(endpoint)

try:
    bing_search_client = BingSearchAPIWrapper(
        bing_subscription_key=BING_SUBSCRIPTION_KEY, bing_search_url=BING_SEARCH_URL)
except Exception as e:
    logging.error(f"Error creating Bing Search client: {str(e)}")
    bing_search_client = None

def completion_client(prompt, max_tokens, temperature, n, stop, deployment_name):
    logging.info(f"completion client")
    
    endpoint = get_random_endpoint()['base_url']
    azure_openai_client = get_openai_client(endpoint)
    
    response = azure_openai_client.chat.completions.create(
        model=deployment_name,
        messages=[
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": prompt}
        ],
        temperature=temperature,
        max_tokens=max_tokens,
        n=n,
        stop=stop
    )
    logging.info(f"response {response}")
    if response.choices:
        choice = response.choices[0]
        if hasattr(choice, 'message') and hasattr(choice.message, 'content'):
            return choice.message.content
        else:
            logging.error("The choice does not have a 'message' attribute or its 'message' has no 'content'.")
    else:
        logging.error("The response contains no choices.")

    return None

class NewAzureOpenAI(AzureOpenAI):
    stop: List[str] = None
    @property
    def _invocation_params(self):
        params = super()._invocation_params
        params.pop('logprobs', None)
        params.pop('best_of', None)
        params.pop('echo', None)
        return params

def llm_client(deployment_name, overrides):
    logging.info("llmclient")

    endpoint = get_random_endpoint()
    azure_openai_client = get_openai_client(endpoint)

    llm = NewAzureOpenAI(
        deployment_name=deployment_name,
        temperature=overrides.get("temperature") or 0.3,
        openai_api_key=azure_openai_client.api_key if not USE_MANAGED_IDENTITIES else None,
        stop=["\n"]
    )
    return llm
