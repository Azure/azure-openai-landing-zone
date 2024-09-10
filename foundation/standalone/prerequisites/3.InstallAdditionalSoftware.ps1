# Installs Azure Functions Core Tools, PowerShell 7, Python, Static Web Apps CLI

# Set Execution Policy to Bypass
Set-ExecutionPolicy Bypass -Scope Process -Force

# Install Azure Functions Core Tools using Chocolatey
choco install azure-functions-core-tools -y

# Install PowerShell 7 using Chocolatey
choco install powershell-core -y

# Install Python 3 using Chocolatey
choco install python --version=3.8.0 -y

# Use npm (from Node.js) to install the Static Web Apps CLI globally
npm install -g @azure/static-web-apps-cli

# Verify installations
node --version
npm --version
func --version
pwsh --version
python --version
