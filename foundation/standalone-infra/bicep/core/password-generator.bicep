param location string 

resource passwordGenerator 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'passwordGeneratorScript'
  location: location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '3.0'
    scriptContent: '''
  function Get-RandomPassword {
    param (
    [Parameter(Mandatory)]
    [ValidateRange(4,[int]::MaxValue)]
    [int] $length,
    [int] $upper = 1,
    [int] $lower = 1,
    [int] $numeric = 1,
    [int] $special = 1
    )
    
    if($upper + $lower + $numeric + $special -gt $length) {
    throw "number of upper/lower/numeric/special char must be lower or equal to length"
    }
    
    $uCharSet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $lCharSet = "abcdefghijklmnopqrstuvwxyz"
    $nCharSet = "0123456789"
    $sCharSet = "/*-+,!?=()@;:._"
    $charSet = ""
    
    if($upper -gt 0) { $charSet += $uCharSet }
    if($lower -gt 0) { $charSet += $lCharSet }
    if($numeric -gt 0) { $charSet += $nCharSet }
    if($special -gt 0) { $charSet += $sCharSet }
    
    $charSet = $charSet.ToCharArray()
    
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $bytes = New-Object byte[]($length)
    $rng.GetBytes($bytes)
    
    $result = New-Object char[]($length)
    for ($i = 0 ; $i -lt $length ; $i++) {
    $result[$i] = $charSet[$bytes[$i] % $charSet.Length]
    }
    $password = (-join $result)
    
    $valid = $true
    if($upper -gt ($password.ToCharArray() | Where-Object {$_ -cin $uCharSet.ToCharArray() }).Count) { $valid = $false }
    if($lower -gt ($password.ToCharArray() | Where-Object {$_ -cin $lCharSet.ToCharArray() }).Count) { $valid = $false }
    if($numeric -gt ($password.ToCharArray() | Where-Object {$_ -cin $nCharSet.ToCharArray() }).Count) { $valid = $false }
    if($special -gt ($password.ToCharArray() | Where-Object {$_ -cin $sCharSet.ToCharArray() }).Count) { $valid = $false }
    
    if(!$valid) {
    $password = Get-RandomPassword $length $upper $lower $numeric $special
    }
    
    return $password
    }
    # Generate a secure random password
    $output = RandomPassword 16
    Write-Output $output
    $DeploymentScriptOutputs = @{}
    $DeploymentScriptOutputs['output'] = $output
    '''
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    
  }
}

#disable-next-line outputs-should-not-contain-secrets
output generatedPassword string = passwordGenerator.properties.outputs.output
