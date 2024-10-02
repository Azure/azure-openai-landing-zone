using './main.bicep'

param location  = 'canadaeast'
param locationFomsRecogniser  ='canadacentral'
param locationStaticWebApp  ='westus2'
param locationOpenAI  = 'canadaeast'
param env  = 'dev'
param postFix  = '-97'
param globalName ='aoai-standhd'


param vnet_name  = 'vnet-ai-standalone${postFix}'
param addressPrefixParam  = '11.0.0.0/16'
param aiSubnetAddressPrefixParam  = '11.0.0.0/24'
param azureBastionSubnetAddressPrefix  = '11.0.1.0/24'
param privateEndpointSubnetAddressPrefixParam  = '11.0.2.0/24'
param jumpboxSubnetAddressPrefixParam  = '11.0.3.0/24'
param appSubnetAddressPrefix   = '11.0.4.0/24'

  
param gptDeploymentName = 'gpt-4'
param searchIndexName = 'idx-${globalName}'
param chatGptModelVersion  ='1106-Preview'
param chatGptDeploymentCapacity  = 5
param embeddingDeploymentName  =  'text-embedding-ada-002'
param embeddingModelName  =  'text-embedding-ada-002'
param embeddingDeploymentCapacity  =5

param searchServiceName  = 'ais-${globalName}-${env}${postFix}'
param skuName  = 'basic'
param privateEndpointName  =  'pe-search-oai-${env}${postFix}'
param privateDnsZoneNameSearch  = 'privatelink.search.windows.net'

param keyvaultName  = 'kv-oai-standalone-${env}${postFix}'
param keyvaultPleName  = 'pv-kv-oai-${env}${postFix}'

param privateEndpointOpenAIName  = 'pe-oai-${env}${postFix}'
param skuOpenAI  = 'S0'
param OpenAIName  = 'oai-standalone-${env}${postFix}'
param privateDnsZoneNameOpenAI  = 'privatelink.openai.azure.com'

param privateEndpointDocumentIntelligenceName  = 'pe-form-${env}${postFix}'
param skuDocumentIntelligence  = 'S0'
param DocumentIntelligenceName  ='frm-${globalName}-${env}${postFix}' 
param privateDnsZoneNameDocumentIntelligence  = 'privatelink.cognitiveservices.azure.com'

param  storageEndpointDocumentIntelligenceName    = 'pe-storage-${env}${postFix}'   

param appServicePlanName  = 'asp-03-${env}${postFix}'
param azFunctionName  = 'afn-${globalName}-${env}${postFix}'
param staticWebsiteName  = 'swa-${globalName}-${env}${postFix}'

param tempBastionPassword  = 'P@ssw0rd1234'
