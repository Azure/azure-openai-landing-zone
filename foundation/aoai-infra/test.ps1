# PowerShell script

# Read Azure OpenAI Resource Name
$aoaiServiceName = $args[0]
if ($aoaiServiceName -eq $null -or $aoaiServiceName -eq "") {
    Write-Host "Existing Azure OpenAI Resource Name:"
    $aoaiServiceName = Read-Host
}

# Read Azure OpenAI Model Deployment Name
$deploymentName = $args[1]
if ($deploymentName -eq $null -or $deploymentName -eq "") {
    Write-Host "Azure OpenAI Model Deployment Name:"
    $deploymentName = Read-Host
}

# Get Tenant ID
$tenantId = (az account show | ConvertFrom-Json).tenantId

# Get Access Token
$accessToken = (az account get-access-token --resource "https://cognitiveservices.azure.com/" --tenant $tenantId | ConvertFrom-Json).accessToken

# Prepare the header
$headers = @{
    "Content-Type" = "application/json"
    "Authorization" = "Bearer $accessToken"
    "api-type" = "azure_ad"
}

# Prepare the body
$body = @{
    max_tokens = 70
    messages = @(
        @{
            role = "system"
            content = "You are a helpful assistant. Generate full sentence."
        },
        @{
            role = "user"
            content = "Tell me something about Azure OpenAI"
        }
    )
} | ConvertTo-Json

# Invoke the REST API
$uri = "https://$aoaiServiceName.openai.azure.com/openai/deployments/$deploymentName/chat/completions?api-version=2023-05-15"
if (-not [string]::IsNullOrEmpty($aoaiServiceName) -and -not [string]::IsNullOrEmpty($deploymentName)) {
    # Execute the Invoke-RestMethod command and store the result
    $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
    $output = $response.choices[0].message.content
    Write-Output $output

} else {
    Write-Host "Service Name or Deployment Name is missing."
}
