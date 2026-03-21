metadata description = 'ARM Template to deploy an Azure Virtual Machine with enforced allowed SKUs.'

@description('Name of the Virtual Machine.')
param vmName string = 'myVM'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Allowed VM sizes only.')
@allowed([
  'Standard_B2ms'
  'Standard_B1ms'
  'Standard_B4ms'
  'Standard_D2_v3'
  'Standard_DS1_v2'
])
param vmSize string = 'Standard_B2ms'

@description('Administrator username for the VM.')
param adminUsername string

@description('Administrator password for the VM.')
@secure()
param adminPassword string

@description('Allowed storage SKUs for OS disk.')
@allowed([
  'Standard_LRS'
  'Premium_LRS'
])
param osDiskStorageAccountType string = 'Standard_LRS'

@description('Windows OS version for the VM image.')
@allowed([
  '2019-Datacenter'
  '2022-Datacenter'
  '2025-Datacenter'
])
param windowsOSVersion string = '2022-Datacenter'

@description('Name of the Virtual Network.')
param virtualNetworkName string = 'myVNet'

@description('Name of the subnet.')
param subnetName string = 'mySubnet'

@description('Name of the Network Security Group.')
param networkSecurityGroupName string = 'myNSG'

@description('Name of the Public IP address resource.')
param publicIpAddressName string = 'myPublicIP'

@description('Name of the Network Interface.')
param networkInterfaceName string = 'myNIC'

var vnetAddressPrefix = '10.0.0.0/16'
var subnetAddressPrefix = '10.0.0.0/24'
var subnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowRDP'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
    ]
  }
}

resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: publicIpAddressName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIpAddress.id
          }
          subnet: {
            id: subnetRef
          }
        }
      }
    ]
  }
  dependsOn: [
    virtualNetwork
  ]
}

resource vm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: windowsOSVersion
        version: 'latest'
      }
      osDisk: {
        name: '${vmName}-OsDisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskStorageAccountType
        }
        diskSizeGB: 128
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

output vmResourceId string = vm.id
output vmName string = vmName
output publicIPAddress string = publicIpAddress.properties.ipAddress
output privateIPAddress string = networkInterface.properties.ipConfigurations[0].properties.privateIPAddress
output vmSize string = vmSize
output storageAccountType string = osDiskStorageAccountType
