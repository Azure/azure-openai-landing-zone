import logging
import os
import random
from typing import List

from openai import AzureOpenAI
from azure.core.credentials import AzureKeyCredential
from azure.identity import DefaultAzureCredential
from azure.search.documents import SearchClient
from azure.search.documents.indexes import SearchIndexClient
from azure.storage.blob import BlobServiceClient
from langchain.utilities import BingSearchAPIWrapper
from azure.identity import DefaultAzureCredential
from azure.identity import get_bearer_token_provider

# Replace these with your own values, either in environment variables or directly here
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

# Define a function to get a random endpoint from the list
def get_random_endpoint():
    endpoint = random.choice(api_endpoints)
    return endpoint

# If you encounter a blocking error during a DefaultAzureCredntial resolution, you can exclude the problematic credential by using a parameter (ex. exclude_shared_token_cache_credential=True)
azure_credential = DefaultAzureCredential()

index_client = SearchIndexClient(endpoint=f"https://{AZURE_SEARCH_SERVICE}.search.windows.net/",
                                 credential=AzureKeyCredential(AZURE_SEARCH_KEY))

# Set up clients for Cognitive Search and Storage
search_client = SearchClient(
    endpoint=f"https://{AZURE_SEARCH_SERVICE}.search.windows.net",
    index_name=AZURE_SEARCH_INDEX,
    credential=AzureKeyCredential(AZURE_SEARCH_KEY))
blob_client = BlobServiceClient(
    account_url=f"https://{AZURE_STORAGE_ACCOUNT}.blob.core.windows.net",
    credential=azure_credential)
blob_container = blob_client.get_container_client(AZURE_STORAGE_CONTAINER)

default_creds = azure_credential if AZURE_STORAGE_KEY == None else AzureKeyCredential(
    AZURE_STORAGE_KEY)
# search_creds = azure_credential if AZURE_SEARCH_KEY == None else AzureKeyCredential(
#     AZURE_SEARCH_KEY)
formrecognizer_creds = azure_credential if AZURE_FORM_RECOGNIZER_KEY == None else AzureKeyCredential(
    AZURE_FORM_RECOGNIZER_KEY)

try:
    bing_search_client = BingSearchAPIWrapper(
        bing_subscription_key=BING_SUBSCRIPTION_KEY, bing_search_url=BING_SEARCH_URL)
except Exception as e:
    logging.error(
        f"Error creating Bing Search client: {str(e)}")
    bing_search_client = None
try:
    bing_search_client = BingSearchAPIWrapper(
        bing_subscription_key=BING_SUBSCRIPTION_KEY, bing_search_url=BING_SEARCH_URL)
except Exception as e:
    logging.error(
        f"Error creating Bing Search client: {str(e)}")
    bing_search_client = None

def ensure_openai_token():
    global openai_token
    # if openai_token.expires_on < int(time.time()) - 60:
    #     openai_token = azure_credential.get_token(
    #         "https://cognitiveservices.azure.com/.default")
    #     openai.api_key = openai_token.token

def completion_client(prompt, max_tokens, temperature, n, stop, deployment_name):
    logging.info(f"completion client")
   
    token_provider = get_bearer_token_provider(
        DefaultAzureCredential(), "https://cognitiveservices.azure.com/.default"
    )
    logging.info(f"token: ${token_provider}")
    endpoint = get_random_endpoint()['base_url']
    logging.info(f"endpoint ${endpoint}")
    azure_openai_client = AzureOpenAI(
    azure_endpoint=endpoint,  # Update with actual endpoint from your environment variables
    azure_ad_token_provider=token_provider,
    api_version= "2023-12-01-preview" # Update with actual API version from your environment variables
    )        
    # Use the `chat.completions.create` method provided by the Azure OpenAI client
    logging.info(f"beforecompletion")
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
    logging.info(f"response ${response}")
    if response.choices:
        choice = response.choices[0]  # Get the first choice, assuming there's at least one choice.
        if hasattr(choice, 'message') and hasattr(choice.message, 'content'):
            completion = choice.message.content  # The actual content of the completion.
        else:
            logging.error("The choice does not have a 'message' attribute or its 'message' has no 'content'.")
    else:
        logging.error("The response contains no choices.")      
    logging.info(f"completion ${completion}")
    return completion
    
            
        
class NewAzureOpenAI(AzureOpenAI):
    stop: List[str] = None
    @property
    def _invocation_params(self):
        params = super()._invocation_params
        # fix InvalidRequestError: logprobs, best_of and echo parameters are not available on gpt-35-turbo model.
        params.pop('logprobs', None)
        params.pop('best_of', None)
        params.pop('echo', None)
        # params['stop'] = self.stop
        return params

def llm_client(deployment_name, overrides):
            logging.info(f"llmclient")
            token_provider = get_bearer_token_provider(
            DefaultAzureCredential(), "https://cognitiveservices.azure.com/.default"
            )
            logging.info(f"token ${token_provider}")
            aoai_endpoint = get_random_endpoint()

            logging.info(f"Using Azure OpenAI endpoint: {aoai_endpoint['base_url']}")
            logging.info(f"Using Azure GPT deployment: {AZURE_OPENAI_GPT_DEPLOYMENT}")

           

            llm = NewAzureOpenAI(deployment_name=deployment_name, temperature=overrides.get("temperature") or 0.3, openai_api_key=token_provider, stop=["\n"]) # type: ignore
            return llm
        