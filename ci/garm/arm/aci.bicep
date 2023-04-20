@description('Name for the container group')
param Name string

@description('Location for all resources.')
param Location string

@description('Storage Account Name for Caddy File Share')
param StorageAccount string

@description('DNS Name Label for the Public IP Address')
param DnsNameLabel string

param Image string = 'mcr.microsoft.com/azuredocs/aci-helloworld'

resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' existing = {
  name: StorageAccount
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-09-01' = {
  name: '${storageAccount.name}/default/${Name}'
}

resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2021-09-01' = {
  name: Name
  location: Location
  properties: {
    containers: [
      {
        name: 'app'
        properties: {
          image: Image
          environmentVariables: [
            // note: Caddy requires port 80 & 443 to be exposed
            {
              name: 'PORT'
              value: '3000'
            }
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: json('0.5')
            }
          }
        }
      }
      {
        name: 'caddy'
        properties: {
          image: 'caddy:2.6.4'
          ports: [
            {
              port: 80
              protocol: 'TCP'
            }
            {
              port: 443
              protocol: 'TCP'
            }
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: json('0.5')
            }
          }
          volumeMounts: [
            {
              name: 'caddy-data'
              mountPath: '/data'
            }
          ]
          command: [
            'caddy'
            'reverse-proxy'
            '--from'
            '${DnsNameLabel}.${Location}.azurecontainer.io'
            '--to'
            'localhost:3000'
          ]
        }
      }
    ]
    osType: 'Linux'
    ipAddress: {
      type: 'Public'
      ports: [
        {
          port: 80
          protocol: 'TCP'
        }
        {
          port: 443
          protocol: 'TCP'
        }
      ]
      dnsNameLabel: DnsNameLabel
    }
    volumes: [
      {
        name: 'caddy-data'
        azureFile: {
          shareName: Name
          storageAccountName: storageAccount.name
          storageAccountKey: listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value
        }
      }
    ]
  }
}
