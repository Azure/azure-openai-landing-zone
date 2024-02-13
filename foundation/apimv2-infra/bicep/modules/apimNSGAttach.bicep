//****************************************************************************************
// Parameters
//****************************************************************************************

param subnetFullName string

param properties object

//****************************************************************************************
// Existing resource references
//****************************************************************************************

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' = {
  name: subnetFullName
  properties: properties
}
