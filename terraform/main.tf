resource "azurerm_resource_group" "workload" {
  name     = var.workload_resource_group_name
  location = var.location
}

resource "azuread_group" "security_reviewers" {
  display_name     = "SG-SecurityReviewers"
  security_enabled = true
}

resource "azurerm_user_assigned_identity" "workload_identity" {
  name                = "mi-workload-identity"
  resource_group_name = var.security_resource_group_name
  location            = var.location
}

resource "azurerm_role_assignment" "reviewers_reader" {
  scope                = azurerm_resource_group.workload.id
  role_definition_name = "Reader"
  principal_id         = azuread_group.security_reviewers.object_id
}

resource "azurerm_role_assignment" "identity_reader" {
  scope                = azurerm_resource_group.workload.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.workload_identity.principal_id
}
