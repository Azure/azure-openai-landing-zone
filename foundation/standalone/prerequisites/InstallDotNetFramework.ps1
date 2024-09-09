# Installs .NET Framework 4.8

# Set Execution Policy to Bypass
Set-ExecutionPolicy Bypass -Scope Process -Force

# Download and install .NET Framework 4.8
$DotNet48InstallerUrl = 'https://download.visualstudio.microsoft.com/download/pr/2d6bb6b2-226a-4baa-bdec-798822606ff1/8494001c276a4b96804cde7829c04d7f/ndp48-x86-x64-allos-enu.exe'
$DotNet48InstallerPath = "$env:TEMP\ndp48-x86-x64-allos-enu.exe"

# Download the .NET Framework 4.8 installer
Invoke-WebRequest -Uri $DotNet48InstallerUrl -OutFile $DotNet48InstallerPath

# Install .NET Framework 4.8
Start-Process -FilePath $DotNet48InstallerPath -ArgumentList "/quiet /norestart" -Wait

# Cleanup the .NET Framework installer
Remove-Item -Force -Path $DotNet48InstallerPath

# Reboot the system to complete installation
Restart-Computer
