variable "alert_email" {
  description = "Email that receives role-assignment change alerts. Leave empty to skip creating the alert."
  type        = string
  default     = ""
}

resource "azurerm_monitor_action_group" "security" {
  count               = var.alert_email == "" ? 0 : 1
  name                = "ag-security-alerts"
  resource_group_name = azurerm_resource_group.security.name
  short_name          = "secalerts"

  email_receiver {
    name          = "security-owner"
    email_address = var.alert_email
  }
}

# Fires whenever any RBAC role assignment is created anywhere in the subscription.
resource "azurerm_monitor_activity_log_alert" "role_assignment_write" {
  count               = var.alert_email == "" ? 0 : 1
  name                = "alert-role-assignment-created"
  resource_group_name = azurerm_resource_group.security.name
  scopes              = ["/subscriptions/${var.subscription_id}"]
  description         = "Fires on any new RBAC role assignment in the subscription"

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.Authorization/roleAssignments/write"
  }

  action {
    action_group_id = azurerm_monitor_action_group.security[0].id
  }
}
