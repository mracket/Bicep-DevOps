using './Modules/app_service_full.bicep'

param app_service_type = 'Internal'
param location = 'WestEurope'
param project_name = 'cnj-demo3'
param virtual_network_name = 'vnet-webapp-d'
param virtual_network_resource_group_name = 'rg-webapp-networking-d'
param virtual_network_subscription_id = '96e45380-182e-463d-a233-f14e1d375313'
param virtual_network_subnet_name = 'snet-cnjdemo1-d'

