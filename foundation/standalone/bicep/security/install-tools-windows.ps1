# The script will be downloaded into the VM: C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.10.15\Downloads\0

# Install chocolately
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install Terminal (already installed in Windows 11)
# choco install microsoft-windows-terminal -y

## Start Terminal

# Install Azure CLI
choco install azure-cli -y
# Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi

# Install Terraform
choco install terraform -y

# Install jq
choco install jq -y

# Install yq
choco install yq -y

# Install VS Code
choco install vscode -y

# Install Git
choco install git -y

choco install openssl -y

# Install curl
choco install curl -y

# Install python
choco install python -y

# # (Optional) Install Docker for Desktop
# choco install docker-desktop -y
# choco install docker-cli -y

# Configure Auto-Complete
Set-ExecutionPolicy RemoteSigned
# Create profile when not exist
if (!(Test-Path -Path $PROFILE.CurrentUserAllHosts)) {
  New-Item -ItemType File -Path $PROFILE.CurrentUserAllHosts -Force
}
# Open the profile with an editor (e.g. good old Notepad)
# ii $PROFILE.CurrentUserAllHosts
# In the editor add the following lines to the profile:
$powershellProfile=@"
# Shows navigable menu of all options when hitting Tab
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# Autocompletion for arrow keys
Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward

Import-Module posh-git

Import-Module PSReadLine
Set-PSReadLineOption -colors @{ Default = "Green"}
Set-PSReadLineOption -colors @{ Parameter = "Blue"}
Set-PSReadLineOption -colors @{ Command = "Magenta"}

function prompt {
" $ "
}

Import-Module Terminal-Icons

Clear

pwd

"@

$powershellProfile > $PSHOME\Profile.ps1 # $PROFILE.CurrentUserAllHosts

# # Set up language preference
# $LanguageList = Get-WinUserLanguageList
# $LanguageList.Add("fr-FR")
# Set-WinUserLanguageList $LanguageList

## Restart Terminal

# # Install Terraform extension in VS Code
code --install-extension hashicorp.terraform
code --install-extension ms-azuretools.vscode-azureterraform

code --install-extension Postman.postman-for-vscode

code --install-extension github.copilot

code --install-extension ms-kubernetes-tools.vscode-kubernetes-tools
code --install-extension ms-kubernetes-tools.vscode-aks-tools
code --install-extension ms-azuretools.vscode-azurecontainerapps
code --install-extension ms-azuretools.vscode-docker

code --install-extension ms-vscode.vscode-node-azure-pack
code --install-extension ms-azuretools.vscode-azureresourcegroups
code --install-extension ms-azuretools.vscode-azurevirtualmachines
code --install-extension ms-vscode.azurecli
code --install-extension ms-azure-devops.azure-pipelines

# az login --identity

# install Powershell Core
choco install powershell-core -y

cd .\Desktop\
git clone https://github.com/HoussemDellai/aks-enterprise
cd aks-enterprise
code .




<# Custom Script for Windows to install a file from Azure Storage using the staging folder created by the deployment script #>
param (
    [string]$artifactsLocation,
    [string]$artifactsLocationSasToken,
    [string]$folderName,
    [string]$fileToInstall
)

$source = $artifactsLocation + "\$folderName\$fileToInstall" + $artifactsLocationSasToken
$dest = "C:\WindowsAzure\$folderName"
New-Item -Path $dest -ItemType directory
Invoke-WebRequest $source -OutFile "$dest\$fileToInstall"

