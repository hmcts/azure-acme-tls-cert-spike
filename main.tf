
resource "azurerm_resource_group" "acme-test" {
  location = var.location
  name     = var.name
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "acme-test" {
  location            = var.location
  name                = var.name
  resource_group_name = azurerm_resource_group.acme-test.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
}

resource "azurerm_app_service_plan" "acme-test" {
  location            = var.location
  name                = var.name
  resource_group_name = azurerm_resource_group.acme-test.name
  kind                = "functionapp"
  reserved            = false
  sku {
    size = "Y1"
    tier = "Dynamic"
  }
}

resource "azurerm_application_insights" "acme-test" {
  application_type    = "web"
  location            = var.location
  name                = var.name
  resource_group_name = azurerm_resource_group.acme-test.name
}

resource "azurerm_storage_account" "acme-test" {
  name                     = replace(var.name, "-", "")
  resource_group_name      = azurerm_resource_group.acme-test.name
  location                 = azurerm_resource_group.acme-test.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_function_app" "acme-test" {
  name                       = var.name
  location                   = azurerm_resource_group.acme-test.location
  resource_group_name        = azurerm_resource_group.acme-test.name
  app_service_plan_id        = azurerm_app_service_plan.acme-test.id
  storage_account_name       = azurerm_storage_account.acme-test.name
  storage_account_access_key = azurerm_storage_account.acme-test.primary_access_key
  version                    = "~3"

  identity {
    type = "SystemAssigned"
  }

  auth_settings {
    enabled                       = true
    unauthenticated_client_action = "RedirectToLoginPage"
    default_provider              = "AzureActiveDirectory"
    active_directory {
      client_id = var.client_id
    }
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY"             = azurerm_application_insights.acme-test.instrumentation_key
    "ApplicationInsightsAgent_EXTENSION_VERSION" = "~2"
    APPLICATIONINSIGHTS_CONNECTION_STRING        = "InstrumentationKey=${azurerm_application_insights.acme-test.instrumentation_key};IngestionEndpoint=https://uksouth-0.in.applicationinsights.azure.com/"
    AzureWebJobsStorage                          = azurerm_storage_account.acme-test.primary_connection_string
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING     = azurerm_storage_account.acme-test.primary_connection_string
    WEBSITE_CONTENTSHARE                         = var.name
    WEBSITE_RUN_FROM_PACKAGE                     = "https://shibayan.blob.core.windows.net/azure-keyvault-letsencrypt/v3/latest.zip"
    FUNCTIONS_WORKER_RUNTIME                     = "dotnet"
    "Acmebot:AzureDns:SubscriptionId"            = var.dns_zone_subscription_id
    //    "Acmebot:AzureDns:SubscriptionId"        = data.azurerm_client_config.current.subscription_id
    "Acmebot:Contacts"     = "cnp-acme-owner@hmcts.net"
    "Acmebot:Endpoint"     = "https://acme-v02.api.letsencrypt.org/"
    "Acmebot:VaultBaseUrl" = azurerm_key_vault.acme-test.vault_uri
    "Acmebot:Environment"  = "AzureCloud"
  }
}

// unable to get this to work
// this describes it well: https://github.com/terraform-providers/terraform-provider-azurerm/issues/6021
// when automating could use az cli for now added manually
//resource "azurerm_key_vault_access_policy" "acme-test" {
//  key_vault_id = azurerm_key_vault.acme-test.id
//  object_id = azurerm_function_app.acme-test.identity[0].principal_id
//  application_id = "ef0c096b-da1c-4d95-91e9-32ec2f66ca3b"
//
//  tenant_id = azurerm_function_app.acme-test.identity[0].tenant_id
//
//  certificate_permissions = [
//    "list",
//    "update",
//    "create",
//    "import",
//    "delete",
//    "managecontacts",
//    "manageissuers",
//    "getissuers",
//    "listissuers",
//    "setissuers",
//    "deleteissuers",
//  ]
//}

output "function_identity" {
  value = azurerm_function_app.acme-test.identity[0].principal_id
}
