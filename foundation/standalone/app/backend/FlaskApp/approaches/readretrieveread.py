from azure.search.documents import SearchClient
from azure.search.documents.models import QueryType
from langchain.agents import AgentExecutor, Tool, ZeroShotAgent
from langchain.callbacks.base import CallbackManager
from langchain.chains import LLMChain

from ..clients import BING_SUBSCRIPTION_KEY, llm_client, search_client
from ..langchainadapters import HtmlCallbackHandler
from ..lookuptool import pandas_lookup, web_search
from ..text import nonewlines
from .approach import Approach


# Attempt to answer questions by iteratively evaluating the question to see what information is missing, and once all information
# is present then formulate an answer. Each iteration consists of two parts: first use GPT to see if we need more information, 
# second if more data is needed use the requested "tool" to retrieve it. The last call to GPT answers the actual question.
# This is inspired by the MKRL paper[1] and applied here using the implementation in Langchain.
# [1] E. Karpas, et al. arXiv:2205.00445
class ReadRetrieveReadApproach(Approach):

#     template_prefix = \
# "You are an intelligent assistant helping Contoso Inc employees with their healthcare plan questions and employee handbook questions. " \
# "Answer the question using only the data provided in the information sources below. " \
# "For tabular information return it as an html table. Do not return markdown format. " \
# "Each source has a name followed by colon and the actual data, quote the source name for each piece of data you use in the response. " \
# "For example, if the question is \"What color is the sky?\" and one of the information sources says \"info123: the sky is blue whenever it's not cloudy\", then answer with \"The sky is blue [info123]\" " \
# "It's important to strictly follow the format where the name of the source is in square brackets at the end of the sentence, and only up to the prefix before the colon (\":\"). " \
# "If there are multiple sources, cite each one in their own square brackets. For example, use \"[info343][ref-76]\" and not \"[info343,ref-76]\". " \
# "Never quote tool names as sources." \
# "If you cannot answer using the sources below, say that you don't know. " \
# "\n\nYou can access to the following tools:"

    template_prefix = \
        "## You are the chat bot helping users answer questions with their documents:" \
        "- You should **not generate response with repeating sentences and repeating code**." \
        "- Your responses should be always formatted in markdown." \
        "It's important to strictly follow the format where the name of the source is in square brackets at the end of the sentence, and only up to the prefix before the colon (\":\"). " \
        "If there are multiple sources, cite each one in their own square brackets. For example, use \"[info343][ref-76]\" and not \"[info343,ref-76]\". " \
        "## On your ability to answer question based on fetched documents:" \
        "- You should always leverage the fetched documents when the user is seeking information or whenever fetched documents could be potentially helpful, regardless of your internal knowledge or information." \
        "- You can leverage past responses and fetched documents for generating relevant and interesting suggestions for the next user turn." \
        "- You can only issue references to the documents as citation examples below. You should **never generate** URLs or links apart from the ones provided in retrieval documents." \
        "- You **should always** reference factual statements to the search results." \
        "- Fetched documents may be incomplete or irrelevant. You don't make assumptions on the fetched documents beyond strictly what's returned." \
        "- If the fetched documents do not contain sufficient information to answer user message completely, you can only include **facts from the fetched documents** and does not add any  nformation by itself."\
        "- You can leverage information from multiple fetched documents to respond **comprehensively**." \
        "## On your ability to answer question based on fetched documents:" \
        "- You should leverage lookup tool only for looking up information about employees and their info in lookup tool." \
        "- For example, if the question is \"what is {input} insurance plan and does it cover eye exams?\" then lookup for insurance plan details for {input}." \
        " If pandas lookup return Empty DataFrame, then say that you don't know. For example if the question is \"what is {input} insurance group?\" and {input} is not in lookup tool you should say \"i dont know\" and **stop** performing any further search or action" \
        "- You should leverage cognitive search to search for the answer. For example, if the question is \"does health insurance cover include eye exams?\" then look up that health insurance plan via cognitive search and construct your response" \
        "- You should **only** leverage bing search if you user specifically requests for latest or up-to date information" \
        "- You should **never** leverage search if you can find answer from internal information sources" \
        "- Do not guess answers. If you cannot answer using the sources below, say that you don't know. " \
        "- Your response should directly answer the question. Do not answer based on just lookup." \
        "\n\nYou can access to the following tools:"


    template_suffix = """
Begin!

Question: {input}

Thought: {agent_scratchpad}"""    

    CognitiveSearchToolDescription = "useful for searching the Microsoft employee benefits information such as healthcare plans, retirement plans, etc."
    PandasLookupToolDescription = "useful to lookup details about employees and their info"
    BingSearchToolDescription = "useful for searching latest information from the web and only if you cannot find answer from internal information sources"

    def __init__(self, search_client: SearchClient, openai_deployment: str, sourcepage_field: str, content_field: str):
        # self.search_client = search_client
        self.openai_deployment = openai_deployment
        self.sourcepage_field = sourcepage_field
        self.content_field = content_field

    def retrieve(self, q: str, overrides: dict) -> any: # type: ignore
        use_semantic_captions = True if overrides.get("semantic_captions") else False
        top = overrides.get("top") or 3
        exclude_category = overrides.get("exclude_category") or None
        filter = "category ne '{}'".format(exclude_category.replace("'", "''")) if exclude_category else None

        if overrides.get("semantic_ranker"):
            r = search_client.search(q,
                                          filter=filter, 
                                          query_type=QueryType.SEMANTIC, 
                                          query_language="en-us", 
                                          query_speller="lexicon", 
                                          semantic_configuration_name="default", 
                                          top = top,
                                          query_caption="extractive|highlight-false" if use_semantic_captions else None)
        else:
            r = search_client.search(q, filter=filter, top=top)
        if use_semantic_captions:
            self.results = [doc[self.sourcepage_field] + ":" + nonewlines(" -.- ".join([c.text for c in doc['@search.captions']])) for doc in r]
        else:
            self.results = [doc[self.sourcepage_field] + ":" + nonewlines(doc[self.content_field][:250]) for doc in r]
        content = "\n".join(self.results)
        return content
        
    def run(self, q: str, overrides: dict) -> any: # type: ignore
        # Not great to keep this as instance state, won't work with interleaving (e.g. if using async), but keeps the example simple
        self.results = None

        # Use to capture thought process during iterations
        cb_handler = HtmlCallbackHandler()
        cb_manager = CallbackManager(handlers=[cb_handler])
        
        acs_tool = Tool(name = "CognitiveSearch", func = lambda q: self.retrieve(q, overrides), description = self.CognitiveSearchToolDescription)
        pandas_tool = Tool(name="PandasLookup", func=lambda x: pandas_lookup(x.lower()), description=self.PandasLookupToolDescription)
        bing_tool = Tool(name="BingSearchLookup", func=lambda q: web_search(q), description=self.BingSearchToolDescription)
        # employee_tool = EmployeeInfoTool("Employee1")
        # Default to pandas and acs tool and use bing_tool only if key is added to config
        tools = [pandas_tool, acs_tool]
        if BING_SUBSCRIPTION_KEY:
            tools.append(bing_tool)

        prompt = ZeroShotAgent.create_prompt(
            tools=tools,
            prefix=overrides.get("prompt_template_prefix") or self.template_prefix,
            suffix=overrides.get("prompt_template_suffix") or self.template_suffix,
            input_variables = ["input", "agent_scratchpad"])
        # llm = AzureOpenAI(deployment_name=self.openai_deployment, temperature=overrides.get("temperature") or 0.3, openai_api_key=openai.api_key) # type: ignore
        # llm = OpenAI(model_name=self.openai_deployment, temperature=overrides.get("temperature") or 0.3, openai_api_key=openai.api_key) # type: ignore
        llm = llm_client(deployment_name=self.openai_deployment, overrides=overrides) # type: ignore
        chain = LLMChain(llm = llm, prompt = prompt)
        agent_exec = AgentExecutor.from_agent_and_tools(
            agent = ZeroShotAgent(llm_chain = chain, tools = tools), # type: ignore
            tools = tools, 
            verbose = False,
            max_iterations=5, 
            callback_manager = cb_manager)
        result = agent_exec.run(q)
                
        # Remove references to tool names that might be confused with a citation
        result = result.replace("[CognitiveSearch]", "").replace("[Employee]", "").replace("[PandasLookup]", "").replace("[BingSearchLookup]", "")

        return {"data_points": self.results or [], "answer": result, "thoughts": cb_handler.get_and_reset_log()}

# class EmployeeInfoTool(CsvLookupTool):
#     employee_name: str = ""

#     def __init__(self, employee_name: str):
#         super().__init__(filename = "FlaskApp/data/employeeinfo.csv", key_field = "name", name = "Employee", description = "useful for answering questions about the employee, their benefits and other personal information") # type: ignore
#         self.func = self.employee_info
#         self.employee_name = employee_name

#     def employee_info(self, unused: str) -> str:
#         return self.lookup(self.employee_name) # type: ignore
