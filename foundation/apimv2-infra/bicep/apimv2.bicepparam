using './apimv2.bicep'

param prefix = 'exampleprefix'

param location = 'eastus'

param privateDeployment = true

param virtualNetworkResourceGroupName = 'Shared-Services-Do-Not-Delete'

param virtualNetworkName = 'EastUS-VNet'

param subnetName = 'apim'

param secretsObject = {
  aoaiaustraliaeastkey: {
    secretName: 'aoai-australiaeast-key'
    secretValue: 'aoaiKeyValue'
    endpointURL: 'https://australiaeast.openai.azure.com/openai'
    endpointName: 'aoai-australiaeast-endpoint'
    region: 'australiaeast'
  }

  aoaicanadaeastkey: {
    secretName: 'aoai-canadaeast-key'
    secretValue: 'aoaiKeyValue'
    endpointURL: 'https://canadaeast.openai.azure.com/openai'
    endpointName: 'aoai-canadaeast-endpoint'
    region: 'canadaeast'
  }

  aoaieastus2key: {
    secretName: 'aoai-eastus2-key'
    secretValue: 'aoaiKeyValue'
    endpointURL: 'https://eastus2.openai.azure.com/openai'
    endpointName: 'aoai-eastus2-endpoint'
    region: 'eastus2'
  }

  aoaieastuskey: {
    secretName: 'aoai-eastus-key'
    secretValue: 'aoaiKeyValue'
    endpointURL: 'https://eastus.openai.azure.com/openai'
    endpointName: 'aoai-eastus-endpoint'
    region: 'eastus'
  }

  aoaifrancecentralkey: {
    secretName: 'aoai-francecentral-key'
    secretValue: 'aoaiKeyValue'
    endpointURL: 'https://francecentral.openai.azure.com/openai'
    endpointName: 'aoai-francecentral-endpoint'
    region: 'francecentral'
  }

  aoaijapaneastkey: {
    secretName: 'aoai-japaneast-key'
    secretValue: 'aoaiKeyValue'
    endpointURL: 'https://japaneast.openai.azure.com/openai'
    endpointName: 'aoai-japaneast-endpoint'
    region: 'japaneast'
  }

  aoainorthcentralkey: {
    secretName: 'aoai-northcentral-key'
    secretValue: 'aoaiKeyValue'
    endpointURL: 'https://northcentral.openai.azure.com/openai'
    endpointName: 'aoai-northcentral-endpoint'
    region: 'northcentralus'
  }

  aoainorwayeastkey: {
    secretName: 'aoai-norwayeast-key'
    secretValue: 'aoaiKeyValue'
    endpointURL: 'https://norwayeast.openai.azure.com/openai'
    endpointName: 'aoai-norwayeast-endpoint'
    region: 'norwayeast'
  }

  aoaisouthindiakey: {
    secretName: 'aoai-southindia-key'
    secretValue: 'aoaiKeyValue'
    endpointURL: 'https://southindia.openai.azure.com/openai'
    endpointName: 'aoai-southindia-endpoint'
    region: 'southindia'
  }

  aoaiswedencentralkey: {
    secretName: 'aoai-swedencentral-key'
    secretValue: 'aoaiKeyValue'
    endpointURL: 'https://swedencentral.openai.azure.com/openai'
    endpointName: 'aoai-swedencentral-endpoint'
    region: 'swedencentral'
  }

  aoaiswitzerlandnorthkey: {
    secretName: 'aoai-switzerlandnorth-key'
    secretValue: 'aoaiKeyValue'
    endpointURL: 'https://switzerlandnorth.openai.azure.com/openai'
    endpointName: 'aoai-switzerlandnorth-endpoint'
    region: 'switzerlandnorth'
  }

  aoaiuksouthkey: {
    secretName: 'aoai-uksouth-key'
    secretValue: 'aoaiKeyValue'
    endpointURL: 'https://uksouth.openai.azure.com/openai'
    endpointName: 'aoai-uksouth-endpoint'
    region: 'uksouth'
  }

  aoaiwesteuropekey: {
    secretName: 'aoai-westeurope-key'
    secretValue: 'aoaiKeyValue'
    endpointURL: 'https://westeurope.openai.azure.com/openai'
    endpointName: 'aoai-westeurope-endpoint'
    region: 'westeurope'
  }

  aoaiwestuskey: {
    secretName: 'aoai-westus-key'
    secretValue: 'aoaiKeyValue'
    endpointURL: 'https://westus.openai.azure.com/openai'
    endpointName: 'aoai-westus-endpoint'
    region: 'westus'
  }
}

param APIPolicies = {
  dall_e_3: {
    name: 'dall-e-3'
    policyPath: loadTextContent('../bicep/artifacts/dall-e-3-fullpolicy.xml')
  }
  gpt_4_32k: {
    name: 'gpt-4-32k'
    policyPath: loadTextContent('../bicep/artifacts/gpt-4-32k-fullpolicy.xml')
  }
  gpt_4: {
    name: 'gpt-4'
    policyPath: loadTextContent('../bicep/artifacts/gpt-4-fullpolicy.xml')
  }
  gpt_4_turbo: {
    name: 'gpt-4-turbo'
    policyPath: loadTextContent('../bicep/artifacts/gpt-4-turbo-fullpolicy.xml')
  }
  gpt_4v: {
    name: 'gpt-4v'
    policyPath: loadTextContent('../bicep/artifacts/gpt-4v-fullpolicy.xml')
  }
  gpt_35_turbo_16k: {
    name: 'gpt-35-turbo-16k'
    policyPath: loadTextContent('../bicep/artifacts/gpt-35-turbo-16k-fullpolicy.xml')
  }
  gpt_35_turbo_0301: {
    name: 'gpt-35-turbo-0301'
    policyPath: loadTextContent('../bicep/artifacts/gpt-35-turbo-0301-fullpolicy.xml')
  }
  gpt_35_turbo_0613: {
    name: 'gpt-35-turbo-0613'
    policyPath: loadTextContent('../bicep/artifacts/gpt-35-turbo-0613-fullpolicy.xml')
  }
  gpt_35_turbo_1106: {
    name: 'gpt-35-turbo-1106'
    policyPath: loadTextContent('../bicep/artifacts/gpt-35-turbo-1106-fullpolicy.xml')
  }
  gpt_35_turbo: {
    name: 'gpt-35-turbo'
    policyPath: loadTextContent('../bicep/artifacts/gpt-35-turbo-instruct-fullpolicy.xml')
  }
  text_embedding_ada_002: {
    name: 'text-embedding-ada-002'
    policyPath: loadTextContent('../bicep/artifacts/text-embedding-ada-002-fullpolicy.xml')
  }
  whisper: {
    name: 'whisper'
    policyPath: loadTextContent('../bicep/artifacts/whisper-fullpolicy.xml')
  }
}
