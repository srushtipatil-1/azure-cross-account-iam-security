variable "enable_identity_test" {
  description = "Create a short-lived ACI that tests the managed identity's effective permissions"
  type        = bool
  default     = false
}

# Runs the Azure CLI as mi-workload-identity (no stored secret) and proves:
# read on the workload RG is allowed, write is denied, and no other RG is visible.
resource "azurerm_container_group" "identity_test" {
  count               = var.enable_identity_test ? 1 : 0
  name                = "aci-mi-access-test"
  location            = var.location
  resource_group_name = azurerm_resource_group.security.name
  os_type             = "Linux"
  restart_policy      = "Never"
  ip_address_type     = "None"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.workload_identity.id]
  }

  container {
    name   = "mi-test"
    image  = "mcr.microsoft.com/azure-cli:latest"
    cpu    = 0.5
    memory = 1

    environment_variables = {
      CLIENT_ID   = azurerm_user_assigned_identity.workload_identity.client_id
      WORKLOAD_RG = azurerm_resource_group.workload.name
    }

    commands = ["/bin/sh", "-c", <<-EOT
      echo "== 1. Authenticate as managed identity (no stored credential)"
      az login --identity --client-id "$CLIENT_ID" --allow-no-subscriptions -o none \
        || az login --identity --username "$CLIENT_ID" --allow-no-subscriptions -o none
      echo "== 2. READ test on workload RG (expect success)"
      az group show -n "$WORKLOAD_RG" --query "{name:name,location:location}" -o table && echo "RESULT: READ ALLOWED (expected)"
      echo "== 3. WRITE test on workload RG (expect AuthorizationFailed)"
      if az group update -n "$WORKLOAD_RG" --set tags.mitest=1 -o none; then
        echo "RESULT: WRITE ALLOWED  <-- least-privilege FAILURE"
      else
        echo "RESULT: WRITE DENIED (expected)"
      fi
      echo "== 4. SCOPE test: resource groups visible to this identity (expect only the workload RG)"
      az group list --query "[].name" -o tsv
    EOT
    ]
  }
}
