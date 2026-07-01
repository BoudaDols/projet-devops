variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "proj-devops"
}

variable "resource_group_name" {
  description = "Azure resource group name"
  type        = string
}

variable "location" {
  description = "Azure location"
  type        = string
}
