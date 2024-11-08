resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = "canadacentral"
}

resource "azuread_application" "app" {
  display_name = var.app_name
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_password" "app_password" {
  application_id = azuread_application.app.id
}

resource "azuread_service_principal" "spn" {
  client_id                    = azuread_application.app.client_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal_password" "secret" {
  service_principal_id = azuread_service_principal.spn.id
}

# Role assignment ( limited to resource group only )
resource "azurerm_role_assignment" "role" {
  scope              = data.azurerm_subscription.primary.id
  principal_id       = data.azuread_service_principal.spn.object_id
  role_definition_name = "Contributor"
  depends_on = [ 
        azuread_service_principal.spn,  azuread_application.app
  ]
}

# Storage blob data contributor role assignment for new SPN
resource "azurerm_role_assignment" "example" {
  scope              = data.azurerm_subscription.primary.id
  principal_id       = data.azuread_service_principal.spn.object_id
  role_definition_name = "Storage Blob Data Contributor"
  depends_on = [ 
        azuread_service_principal.spn,  azuread_application.app
  ]  
}

# Key vault access policy for new service principal
resource "azurerm_key_vault_access_policy" "access" {
  key_vault_id = data.azurerm_key_vault.vault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azuread_service_principal.spn.object_id

  key_permissions = [
    "Get", "List", "Encrypt", "Decrypt", "Create"
  ]

  secret_permissions = [
    "Get", "List", "Set"
  ]

  depends_on = [data.azurerm_key_vault.vault]
}

resource "azurerm_key_vault_secret" "secrets" {
  for_each = tomap({
    "client_id" = {
      name  = "ADO-SPN-1-client-id"
      value = azuread_application.app.client_id
    }
    "secret" = {
      name  = "ADO-SPN-1-client-secret"
      value = azuread_service_principal_password.secret.value
    }
    "tenant_id" = {
      name  = "ADO-SPN-1-tenant-id"
      value = azuread_service_principal.spn.application_tenant_id
    }
  })
  name         = each.value.name
  value        = each.value.value
  key_vault_id = data.azurerm_key_vault.vault.id

  depends_on = [azurerm_key_vault_access_policy.access, data.azurerm_key_vault.vault]
}