import logging
import azure.functions as func
from ..FlaskApp import app

logging.info("Python HTTP HandleApproach trigger - Entry point initialized.")

def main(req: func.HttpRequest, context: func.Context) -> func.HttpResponse:
    """Each request is redirected to the WSGI handler.
    """
    logging.info(f"Python HTTP trigger function processed a request. RequestUri={req.url}")
    # logging.info(f"url map: {app.url_map}")
    return func.WsgiMiddleware(app.wsgi_app).handle(req, context)
