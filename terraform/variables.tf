variable "subscription_id" {
  description = "Azure subscription ID where resources will be managed"
  type        = string
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "centralindia"
}

variable "security_resource_group_name" {
  description = "Name of the Security/Admin resource group"
  type        = string
  default     = "rg-cross-account-iam-security"
}

variable "workload_resource_group_name" {
  description = "Name of the Workload resource group"
  type        = string
  default     = "rg-workload-environment"
}
