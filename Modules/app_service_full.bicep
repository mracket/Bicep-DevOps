extension microsoftGraphV1

param alwaysOn bool = true
param app_minTlsVersion string = '1.3'
@allowed([
  'Internal'
  'External'
])
param app_service_type string= 'External'
param ftpsState string = 'Disabled'
param http20enabled bool = true
param key_vault_sku_name string = 'standard'
param key_vault_sku_family string = 'A'
param kind string = 'Linux'
param location string
param project_name string 
param sku_name string = 'B1'
param sku_tier string = 'Basic'
param virtual_network_name string = ''
param virtual_network_resource_group_name string = ''
param virtual_network_subscription_id string = ''
param virtual_network_subnet_name string = ''

var key_vault_secrets_user = '4633458b-17de-408a-b874-0445c86b69e6'

resource appRegistration 'Microsoft.Graph/applications@v1.0' = if(app_service_type == 'External') {
  uniqueName: toLower('app-${project_name}')
  displayName: toLower('app-${project_name}')  
  web: {
    redirectUris: [
      'https://app-${project_name}.azurewebsites.net/.auth/login/aad/callback'
    ]
    implicitGrantSettings: {
      enableIdTokenIssuance: true
      enableAccessTokenIssuance: true
    }
  }
}

resource appRegistrationSp 'Microsoft.Graph/servicePrincipals@v1.0' = if(app_service_type == 'External') {
  appId: appRegistration.appId

}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = if(app_service_type == 'Internal') {
  name: virtual_network_name
  scope: resourceGroup(virtual_network_subscription_id, virtual_network_resource_group_name)
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = if(app_service_type == 'Internal') {
  name: virtual_network_subnet_name
  parent: vnet
}

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: 'asp-${project_name}'
  location: location  
  sku: {
    name: sku_name
    tier: sku_tier
    
  }
  kind: kind
  properties: {
    reserved: (kind == 'Linux') ? true : false
  }
}

resource appService 'Microsoft.Web/sites@2023-12-01' = {
  name: 'app-${project_name}'
  location: location
  properties: {
    serverFarmId: appServicePlan.id  
    virtualNetworkSubnetId: (app_service_type == 'Internal') ? subnet.id : null
    httpsOnly: true
    publicNetworkAccess: (app_service_type == 'Internal') ? 'Disabled' : 'Enabled'     
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource app_config 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: appService
  name: 'web'
  properties: {
    minTlsVersion: app_minTlsVersion
    http20Enabled: http20enabled
    ftpsState: ftpsState
    alwaysOn: alwaysOn          
  }
}

resource authsettingsV 'Microsoft.Web/sites/config@2022-09-01' = if(app_service_type == 'External') {
  parent: appService
  name: 'authsettingsV2'
  properties: {
    platform: {
      enabled: true
      runtimeVersion: '~1'
    }
    globalValidation: {
      requireAuthentication:  true
      unauthenticatedClientAction: 'RedirectToLoginPage'
      redirectToProvider: 'azureactivedirectory'
    }
    identityProviders: {
      azureActiveDirectory: true ? {
        enabled: true
        registration: {
          openIdIssuer: 'https://sts.windows.net/${subscription().tenantId}/v2.0'
          clientId: appRegistration.appId
          clientSecretSettingName: 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET'
        }
        login: {
          disableWWWAuthenticate: false
        }
        validation: {
          jwtClaimChecks: {}
          allowedAudiences: [
            'api://${appRegistration.appId}'
          ]
          defaultAuthorizationPolicy: {
            allowedPrincipals: {}
          }
        }
      } : null
    }
    login: {
      routes: {}
      tokenStore: {
        enabled: true
        tokenRefreshExtensionHours: json('72.0')
        fileSystem: {}
        azureBlobStorage: {}
      }
      preserveUrlFragmentsForLogins: false
      cookieExpiration: {
        convention: 'FixedTime'
        timeToExpiration: '08:00:00'
      }
      nonce: {
        validateNonce: true
        nonceExpirationInterval: '00:05:00'
      }
    }
    httpSettings: {
      requireHttps: true
      routes: {
        apiPrefix: '/.auth'
      }
      forwardProxy: {
        convention: 'NoProxy'
      }
    }
  }
}


resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-${project_name}'
  location: location
  
  properties: {
    sku: {
      name: key_vault_sku_name
      family: key_vault_sku_family
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enabledForDeployment: true
    enabledForTemplateDeployment: true
  }
}

resource keyVaultSecretUser1 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(key_vault_secrets_user,appService.id,keyVault.id)
  properties: {
    principalId: appService.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', key_vault_secrets_user)
  }
  scope: keyVault
}
