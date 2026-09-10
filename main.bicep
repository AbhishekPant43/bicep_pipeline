targetScope = 'resourceGroup'

param aksName string = 'falcon-ai-test-aks'
param location string = resourceGroup().location
param kubernetesVersion string = '1.36.3'

param adminUsername string = 'azureuser'

@secure()
param sshPublicKey string

param systemNodeVmSize string = 'Standard_B2s'
param systemNodeCount int = 1
param systemMinNodeCount int = 1
param systemMaxNodeCount int = 1

param userNodeVmSize string = 'Standard_B2s'
param userNodeCount int = 0
param userMinNodeCount int = 0
param userMaxNodeCount int = 1

param enableMonitoring bool = false

param serviceCidr string = '10.0.0.0/16'
param dnsServiceIP string = '10.0.0.10'
param podCidr string = '10.244.0.0/16'

var environment = 'test'

var commonTags = {
  environment: environment
  managedBy: 'bicep'
  platform: 'aks'
  workload: 'multi-application'
}

resource aks 'Microsoft.ContainerService/managedClusters@2026-02-01' = {
  name: aksName
  location: location

  sku: {
    name: 'Base'
    tier: 'Standard'
  }

  identity: {
    type: 'SystemAssigned'
  }

  properties: {
    kubernetesVersion: kubernetesVersion

    linuxProfile: {
      adminUsername: adminUsername
      ssh: {
        publicKeys: [
          {
            keyData: sshPublicKey
          }
        ]
      }
    }

    agentPoolProfiles: [
      {
        name: 'system'
        mode: 'System'
        count: systemNodeCount
        vmSize: systemNodeVmSize
        osType: 'Linux'
        osSKU: 'Ubuntu'
        type: 'VirtualMachineScaleSets'
        enableAutoScaling: true
        minCount: systemMinNodeCount
        maxCount: systemMaxNodeCount
        maxPods: 30
        osDiskType: 'Managed'
        osDiskSizeGB: 30
      }

      {
        name: 'workerpool'
        mode: 'User'
        count: userNodeCount
        vmSize: userNodeVmSize
        osType: 'Linux'
        osSKU: 'Ubuntu'
        type: 'VirtualMachineScaleSets'
        enableAutoScaling: true
        minCount: userMinNodeCount
        maxCount: userMaxNodeCount
        maxPods: 30
        osDiskType: 'Managed'
        osDiskSizeGB: 30
      }
    ]

    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkPolicy: 'azure'
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
      serviceCidr: serviceCidr
      dnsServiceIP: dnsServiceIP
      podCidr: podCidr
    }

    ingressProfile: {
      webAppRouting: {
        enabled: true
        nginx: {
          defaultIngressControllerType: 'External'
        }
      }
    }

    workloadAutoScalerProfile: {
      keda: {
        enabled: true
      }
      verticalPodAutoscaler: {
        enabled: false
      }
    }

    oidcIssuerProfile: {
      enabled: true
    }

    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }

    enableRBAC: true
    disableLocalAccounts: true

    addonProfiles: {
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'true'
        }
      }

      omsAgent: {
        enabled: enableMonitoring
      }
    }
  }

  tags: commonTags
}

output aksName string = aks.name
output aksResourceId string = aks.id
output aksLocation string = aks.location
output aksKubeletIdentityObjectId string = aks.properties.identityProfile.kubeletidentity.objectId
