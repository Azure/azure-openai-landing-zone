# Installs Node.js

# Set Execution Policy to Bypass
Set-ExecutionPolicy Bypass -Scope Process -Force

# Download and install Chocolatey if not already installed
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

# Refresh the environment to ensure the Chocolatey path is loaded
RefreshEnv.cmd

# Install Node.js using Chocolatey
choco install nodejs -y

# Reboot the system to ensure changes take effect
Restart-Computer
