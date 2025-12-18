@description('Prefix for the container group')
param prefix string = 'eshopcontainer'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Container image to deploy. Should be of the form repoName/imagename:tag for images stored in public Docker Hub, or a fully qualified URI for other registries. Images from private registries require additional registry credentials.')
param image string = 'mcr.microsoft.com/azuredocs/aci-helloworld'

@description('Port to open on the container and the public IP address.')
param port int = 5106

@description('The number of CPU cores to allocate to the container.')
param cpuCores int = 1

@description('The amount of memory to allocate to the container in gigabytes.')
param memoryInGb int = 2

@description('The behavior of Azure runtime if container has stopped.')
@allowed([
  'Always'
  'Never'
  'OnFailure'
])
param restartPolicy string = 'Always'

param server string 

var name = '${prefix}${uniqueString(resourceGroup().id)}'
var acrName = replace(server, '.azurecr.io', '')

resource acr 'Microsoft.ContainerRegistry/registries@2021-09-01' existing = {
  name: acrName
}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: '${name}-identity'
  location: location
}

resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2021-09-01' = {
  name: name
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  properties: {
    containers: [
      {
        name: name
        properties: {
          image: image
          ports: [
            {
              port: port
              protocol: 'TCP'

            }
            {
              port: 80
              protocol: 'TCP'
            }
          ]
          resources: {
            requests: {
              cpu: cpuCores
              memoryInGB: memoryInGb
            }
          }
          environmentVariables: [
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: 'Docker'
            }
            {
              name: 'UseOnlyInMemoryDatabase'
              value: 'true'
            }
            {
              name: 'ASPNETCORE_HTTP_PORTS'
              value: '80'
            }
          ]
        }
      }
    ]
    osType: 'Linux'
    restartPolicy: restartPolicy
    ipAddress: {
      type: 'Public'
      ports: [
        {
          port: port
          protocol: 'TCP'
        }
        {
          port: 80
          protocol: 'TCP'
        }
      ]
    }
    imageRegistryCredentials: [
      {
        identity: identity.id
        server: acr.properties.loginServer
      }
    ]
  }
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(identity.id, 'acrpull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull role
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output containerIPv4Address string = containerGroup.properties.ipAddress.ip
