output "workload_resource_group_id" {
  description = "Resource ID of the workload resource group"
  value       = azurerm_resource_group.workload.id
}

output "security_reviewers_group_id" {
  description = "Object ID of the SG-SecurityReviewers Entra ID group"
  value       = azuread_group.security_reviewers.object_id
}

output "workload_identity_principal_id" {
  description = "Principal ID of the workload managed identity"
  value       = azurerm_user_assigned_identity.workload_identity.principal_id
}
