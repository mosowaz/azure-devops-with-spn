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
resource "azurerm_role_definition" "contributor_role" {
  role_definition_id = "b24988ac-6180-42a0-ab88-20f7382dd24c"
  name               = "${var.rg_name}-contributor"
  scope              = "${data.azurerm_subscription.primary.id}/resourceGroups/${var.rg_name}"

  permissions {
    actions     = ["*"]
    not_actions = []
  }

  assignable_scopes = [
    "${data.azurerm_subscription.primary.id}/resourceGroups/${var.rg_name}",
  ]
}

resource "azurerm_role_assignment" "role" {
  name               = azurerm_role_definition.contributor_role.role_definition_id
  scope              = "${data.azurerm_subscription.primary.id}/resourceGroups/${var.rg_name}"
  role_definition_id = azurerm_role_definition.contributor_role.role_definition_resource_id
  principal_id       = data.azuread_service_principal.spn.object_id
}

# Storage blob data contributor role assignment and definition for new SPN
resource "azurerm_role_definition" "storage_contributor" {
  role_definition_id = "ba92f5b4-2d11-453d-a403-e96b0029c9fe"
  name               = "${var.rg_name}-blob-contributor"
  scope              = "${data.azurerm_subscription.primary.id}/resourceGroups/${var.rg_name}"

  permissions {
    data_actions = [
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/move/action",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/add/action",
    ]
    not_data_actions = []
  }

  assignable_scopes = [
    "${data.azurerm_subscription.primary.id}/resourceGroups/${var.rg_name}",
  ]
}

resource "azurerm_role_assignment" "example" {
  name               = azurerm_role_definition.storage_contributor.role_definition_id
  scope              = "${data.azurerm_subscription.primary.id}/resourceGroups/${var.rg_name}"
  role_definition_id = azurerm_role_definition.contributor_role.role_definition_resource_id
  principal_id       = data.azuread_service_principal.spn.object_id
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

  depends_on = [azurerm_key_vault_access_policy.access, ]
}