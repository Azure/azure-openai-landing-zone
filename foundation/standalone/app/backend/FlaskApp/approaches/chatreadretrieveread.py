import logging
from azure.core.exceptions import HttpResponseError
from azure.search.documents import SearchClient
from azure.search.documents.models import QueryType

from ..clients import completion_client, search_client
from ..text import nonewlines
from .approach import Approach


# Simple retrieve-then-read implementation, using the Cognitive Search and OpenAI APIs directly. It first retrieves
# top documents from search, then constructs a prompt with them, and then uses OpenAI to generate an completion 
# (answer) with that prompt.
class ChatReadRetrieveReadApproach(Approach):
    prompt_prefix = """
You are a virtual assistant. Be brief in your answers.
For tabular information return it as an html table. Do not return markdown format.
{chat_history}
"""
    query_prompt_template = """Below is a history of the conversation so far, if it is empty just ignore it.
    
Chat History:
{chat_history}

Question:
{question}

"""

    def __init__(self, search_client: SearchClient, chatgpt_deployment: str, gpt_deployment: str, sourcepage_field: str, content_field: str):
        # self.search_client = search_client
        self.chatgpt_deployment = chatgpt_deployment
        self.gpt_deployment = gpt_deployment
        self.sourcepage_field = sourcepage_field
        self.content_field = content_field

    def run(self, history: list[dict], overrides: dict) -> any:
        use_semantic_captions = True if overrides.get("semantic_captions") else False
        top = overrides.get("top") or 3
        exclude_category = overrides.get("exclude_category") or None
        filter = "category ne '{}'".format(exclude_category.replace("'", "''")) if exclude_category else None

        # STEP 1: Generate an optimized keyword search query based on the chat history and the last question
        prompt = self.query_prompt_template.format(chat_history=self.get_chat_history_as_text(history, include_last_turn=False), question=history[-1]["user"])

        completion = completion_client(prompt=prompt, max_tokens=32, temperature=0.0, n=1, stop=["\n"], deployment_name=self.gpt_deployment)
        logging.info(f"Generated search query completions: ${completion}")
        q = completion

        logging.info(f"Generated search query: {q}")
        results=[]
        
        try:
            # STEP 2: Retrieve relevant documents from the search index with the GPT optimized query
            if overrides.get("semantic_ranker"):
                r = search_client.search(q, 
                                            filter=filter,
                                            query_type=QueryType.SEMANTIC, 
                                            query_language="en-us", 
                                            query_speller="lexicon", 
                                            semantic_configuration_name="default", 
                                            top=top, 
                                            query_caption="extractive|highlight-false" if use_semantic_captions else None)
            else:
                r = search_client.search(q, filter=filter, top=top)

            if use_semantic_captions:
                results = [doc[self.sourcepage_field] + ": " + nonewlines(" . ".join([c.text for c in doc['@search.captions']])) for doc in r]
            else:
                results = [doc[self.sourcepage_field] + ": " + nonewlines(doc[self.content_field]) for doc in r]
            content = "\n".join(results)

            follow_up_questions_prompt = self.follow_up_questions_prompt_content if overrides.get("suggest_followup_questions") else ""
            
            # Allow client to replace the entire prompt, or to inject into the exiting prompt using >>>
            prompt_override = overrides.get("prompt_template")
            if prompt_override is None:
                prompt = self.prompt_prefix.format(injected_prompt="", sources=content, chat_history=self.get_chat_history_as_text(history), follow_up_questions_prompt=follow_up_questions_prompt)
            elif prompt_override.startswith(">>>"):
                prompt = self.prompt_prefix.format(injected_prompt=prompt_override[3:] + "\n", sources=content, chat_history=self.get_chat_history_as_text(history), follow_up_questions_prompt=follow_up_questions_prompt)
            else:
                prompt = prompt_override.format(sources=content, chat_history=self.get_chat_history_as_text(history), follow_up_questions_prompt=follow_up_questions_prompt)  
       
        except Exception as e:
            if e.status_code == 404:  # Status code for 'Not Found', which may indicate missing index
                logging.error(f"Search index not found: {e}")
            else:
                logging.error(f"Search encountered an error: {e}")
            # Assume no results if index is missing or another error occurred
            results = []

            # You can also set the content to a default message if needed
            content = "No relevant documents found. Proceeding with completion."
            
        # STEP 3: Generate a contextual and content specific answer using the search results and chat history
        completion = completion_client(prompt=prompt, max_tokens=1024, temperature=overrides.get("temperature") or 0, n=1, stop=["<|im_end|>", "<|im_start|>"], deployment_name=self.chatgpt_deployment)

        return {"data_points": results, "answer": completion, "thoughts": f"Searched for:<br>{q}<br><br>Prompt:<br>" + prompt.replace('\n', '<br>')}
    
    def get_chat_history_as_text(self, history, include_last_turn=True, approx_max_tokens=1000) -> str:
        history_text = ""
        for h in reversed(history if include_last_turn else history[:-1]):
            history_text = """<|im_start|>user""" +"\n" + h["user"] + "\n" + """<|im_end|>""" + "\n" + """<|im_start|>assistant""" + "\n" + (h.get("bot") + """<|im_end|>""" if h.get("bot") else "") + "\n" + history_text
            if len(history_text) > approx_max_tokens*4:
                break    
        return history_text