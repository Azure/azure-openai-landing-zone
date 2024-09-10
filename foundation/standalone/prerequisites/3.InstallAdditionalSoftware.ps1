# Installs Azure Functions Core Tools, Azure CLI, PowerShell 7, Python, Static Web Apps CLI, Visual Studio Code, Git, and Git Bash

# Set Execution Policy to Bypass
Set-ExecutionPolicy Bypass -Scope Process -Force

# Refresh the environment to make sure Chocolatey is in the PATH
RefreshEnv.cmd

# Install Azure Functions Core Tools using Chocolatey
choco install azure-functions-core-tools -y

# Install PowerShell 7 using Chocolatey
choco install powershell-core -y

# Install Python 3 using Chocolatey
choco install python --version=3.8.0 -y

# Use npm (from Node.js) to install the Static Web Apps CLI globally
npm install -g @azure/static-web-apps-cli

# Install Visual Studio Code using Chocolatey
choco install vscode -y

# Install Git using Chocolatey, which includes Git Bash
choco install git -y

# Install Azure CLI using MSI

Invoke-WebRequest -Uri https://aka.ms/installazurecliwindowsx64 -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; Remove-Item .\AzureCLI.msi

# Add Azure CLI to the system PATH environment variable

$azureCliPath = "C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin"
$env:Path += ";$azureCliPath"
[System.Environment]::SetEnvironmentVariable('Path', $env:Path, [System.EnvironmentVariableTarget]::Machine)


# Add Git to the system PATH environment variable
$gitPath = "C:\Program Files\Git\cmd"
$env:Path += ";$gitPath"
[System.Environment]::SetEnvironmentVariable('Path', $env:Path, [System.EnvironmentVariableTarget]::Machine)

# Refresh environment to include path updates
RefreshEnv.cmd

# Verify installations
node --version
npm --version
func --version
pwsh --version
py --version
& "C:\Program Files\Microsoft VS Code\bin\code" --version
git --version

# Reboot the system to ensure changes take effect
Restart-Computer
