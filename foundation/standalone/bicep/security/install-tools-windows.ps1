# Install chocolately
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install Azure CLI
choco install azure-cli -y

# Install VS Code
choco install vscode -y

# Install Git
choco install git -y

# Install python
choco install python -y

# Install Azure Functions Core Tools
choco install azure-functions-core-tools -y

# install Powershell Core
choco install powershell-core -y

# Install Node.js
choco install nodejs -y

# Use npm (from Node.js) to install the Static Web Apps CLI globally
npm install -g @azure/static-web-apps-cli
