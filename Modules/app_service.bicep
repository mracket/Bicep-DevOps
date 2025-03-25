param kind string = 'Linux'
param location string
param project_name string 
param sku_name string = 'B1'
param sku_tier string = 'Basic'

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
  }
}
