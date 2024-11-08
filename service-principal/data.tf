data "azuread_client_config" "current" {}

data "azurerm_subscription" "primary" {}

data "azuread_service_principal" "spn" {
  object_id = azuread_service_principal.spn.object_id
}

data "azurerm_client_config" "current" {}

data "azurerm_key_vault" "vault" {
  name                = "my-principal-keyvault"
  resource_group_name = "terraform-backend-RG"
}

