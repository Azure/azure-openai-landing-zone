from os import path
import csv
from langchain.agents import Tool, tool
from typing import Optional
import pandas as pd
import logging
from langchain.utilities import BingSearchAPIWrapper
from .clients import BING_SUBSCRIPTION_KEY, BING_SEARCH_URL

class CsvLookupTool(Tool):
    def __init__(self, filename: path, key_field: str, name: str = "lookup", description: str = "useful to look up details given an input key as opposite to searching data with an unstructured question"):
        super().__init__(name, self.lookup, description) # type: ignore
        self.data = {}
        with open(filename, newline='') as csvfile: # type: ignore
            reader = csv.DictReader(csvfile)
            for row in reader:
                self.data[row[key_field]] =  "\n".join([f"{i}:{row[i]}" for i in row])

    def lookup(self, key: str) -> Optional[str]:
        return self.data.get(key, "")

@tool
def pandas_lookup(query: str,filename:str = 'FlaskApp/data/employeeinfo.csv') -> Optional[str]:
    """
    Looks up details about employees and their info in a pandas dataframe.

    Args:
        filename (str): The name of the CSV file containing the data.
        query (str): The name of the employee to look up.

    Returns:
        str: A string representation of the rows in the dataframe that match the query.
             Returns "No results found." if no matches are found.
    """
    df = pd.read_csv(filename)
    try:
        result = df.loc[df['name'].str.lower() == query.lower()]
        response = result.to_string(index=False)
    except IndexError:
        response= f"{query} is not in pandas dataframe"
    # logging.info("-----------------------")
    # logging.info("response from pandas_lookup: " + response)
    return response

@tool
def web_search(query: str) -> Optional[str]:
    """
    Looks up bing search for latest and relevant news.

    Args:
        query (str): search keyword.

    Returns:
        str: A string representation of search results from bing.
    """
    search = BingSearchAPIWrapper(bing_subscription_key=BING_SUBSCRIPTION_KEY, bing_search_url=BING_SEARCH_URL)
    return search.run(query)
        