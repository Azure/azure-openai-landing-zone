output "apim_name" {
  value = azapi_resource.apim.name
}

output "apim_id" {
  value = azapi_resource.apim.id
}

output "gateway_url" {
  value = jsondecode(azapi_resource.apim.output).properties.gatewayUrl
}

output "principal_id" {
  value = jsondecode(azapi_resource.apim.output).identity.principalId
}
