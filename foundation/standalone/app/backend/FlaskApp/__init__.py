import logging
import mimetypes
import os
import re
from tempfile import mkdtemp

import azure.functions as func
import filetype
from flask import Flask, jsonify, request

from .approaches.chatreadretrieveread import ChatReadRetrieveReadApproach
from .approaches.readdecomposeask import ReadDecomposeAsk
from .approaches.readretrieveread import ReadRetrieveReadApproach
from .approaches.retrievethenread import RetrieveThenReadApproach
# Always use relative import for custom module
from .clients import (AZURE_OPENAI_CHATGPT_DEPLOYMENT,
                      AZURE_OPENAI_GPT_DEPLOYMENT, KB_FIELDS_CONTENT, KB_FIELDS_SOURCEPAGE, blob_container,
                      ensure_openai_token, search_client)
from .cog_services import process_pdf

# Various approaches to integrate GPT and external knowledge, most applications will use a single one of these patterns
# or some derivative, here we include several for exploration purposes
ask_approaches = {
    "rtr": RetrieveThenReadApproach(search_client, AZURE_OPENAI_GPT_DEPLOYMENT, KB_FIELDS_SOURCEPAGE, KB_FIELDS_CONTENT),
    "rrr": ReadRetrieveReadApproach(search_client, AZURE_OPENAI_GPT_DEPLOYMENT, KB_FIELDS_SOURCEPAGE, KB_FIELDS_CONTENT),
    "rda": ReadDecomposeAsk(search_client, AZURE_OPENAI_GPT_DEPLOYMENT, KB_FIELDS_SOURCEPAGE, KB_FIELDS_CONTENT)
}

chat_approaches = {
    "rrr": ChatReadRetrieveReadApproach(search_client, AZURE_OPENAI_CHATGPT_DEPLOYMENT, AZURE_OPENAI_GPT_DEPLOYMENT, KB_FIELDS_SOURCEPAGE, KB_FIELDS_CONTENT)
}

app = Flask(__name__)

# Serve content files from blob storage from within the app to keep the example self-contained. 
# *** NOTE *** this assumes that the content files are public, or at least that all users of the app
# can access all the files. This is also slow and memory hungry.
@app.route("/api/content/<path>")
def content_file(path):
    blob = blob_container.get_blob_client(path).download_blob()
    mime_type = blob.properties["content_settings"]["content_type"] # type: ignore
    if mime_type == "application/octet-stream":
        mime_type = mimetypes.guess_type(path)[0] or "application/octet-stream"
    return blob.readall(), 200, {"Content-Type": mime_type, "Content-Disposition": f"inline; filename={path}"}

@app.route("/api/ask", methods=["POST"])
def ask():
    req = request.get_json(silent=True, force=True)
    logging.info(f"ask request: {req}")
    # ensure_openai_token()
    approach = req["approach"] # type: ignore
    try:
        impl = ask_approaches.get(approach)
        if not impl:
            return jsonify({"error": "unknown approach"}), 400
        r = impl.run(req["question"], req["overrides"] or {}) # type: ignore
        logging.info(f"ask response: {r}")
        return jsonify(r)
    except Exception as e:
        logging.exception("Exception in /ask")
        return jsonify({"error": str(e)}), 500

@app.route("/api/chat", methods=["POST"])
def chat():
    req = request.get_json(silent=True, force=True)
    ensure_openai_token()
    approach = req["approach"] # type: ignore
    try:
        impl = chat_approaches.get(approach)
        if not impl:
            return jsonify({"error": "unknown approach"}), 400
        r = impl.run(req["history"], req["overrides"] or {}) # type: ignore
        return jsonify(r)
    except Exception as e:
        logging.exception("Exception in /chat")
        return jsonify({"error": str(e)}), 500

@app.route("/api/upload", methods=["POST"]) # type: ignore
def upload():
    req = request
     # Check if files are present in the request
    if not req.files: # type: ignore
        return func.HttpResponse(
             "Please upload at least one file",
             status_code=400
        )
    status = {}
    # Process each file
    for _, file in req.files.items(multi=True): # type: ignore
        file_name = file.filename
        logging.info(f"file_name - {file_name}, file - {file.filename}")        
        # Create a temporary directory to store the uploaded files
        secure_temp_dir = mkdtemp(prefix="az_",suffix="_za")
        base_name, ext = os.path.splitext(os.path.basename(file_name)) # type: ignore
        cleaned_filename = re.sub(r'[ .]', '_', base_name)
        file_to_process = os.path.join(secure_temp_dir, cleaned_filename + ext.lower())
        logging.info(f"base_name - {base_name}, ext - {ext}, cleaned_filename - {cleaned_filename}")
        logging.info(f"file to process - {file_to_process}")
        with open(file_to_process, 'wb') as f:
            file_contents = file.read()
            f.write(file_contents)
            file_type ="application/pdf"
            process_pdf(file_to_process)

    logging.info(status)
    return jsonify({ "success":True,"message":"Files processed successfully."}), 200

if __name__ == "__main__":
    app.run()