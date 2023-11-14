
@description('Azure OpenAI Resource Name.')
param aoaiServiceName string

var principalIds = loadJsonContent('./userPrincipalIds.json')

//'Cognitive Services Contributor': resourceId('Microsoft.Authorization/roleAssignments', '25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68')
//'Cognitive Services OpenAI Contributor': resourceId('Microsoft.Authorization/roleAssignments', 'a001fd3d-188f-4b5d-821b-7da978bf7442')
//'Cognitive Services OpenAI User': resourceId('Microsoft.Authorization/roleAssignments', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
//'Cognitive Services User': resourceId('Microsoft.Authorization/roleAssignments', 'a97b65f3-24c7-4388-baec-2e87135dc908')


//var roleAssignmentName= guid(principalId, contributorRoleDefinitionID, cognitiveService.id)
resource cognitiveService 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: aoaiServiceName
}

resource contributorRoleID 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in principalIds.contributorPrincipalIds:  {
  name: guid(principalId, '25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68', cognitiveService.id)
  scope: cognitiveService
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleAssignments', '25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68')
    principalId: principalId
  }
}]


resource userRoleID 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in principalIds.userPrincipalIds:  {
  name: guid(principalId, 'a97b65f3-24c7-4388-baec-2e87135dc908', cognitiveService.id)
  scope: cognitiveService
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleAssignments', 'a97b65f3-24c7-4388-baec-2e87135dc908')
    principalId: principalId
  }
}]

