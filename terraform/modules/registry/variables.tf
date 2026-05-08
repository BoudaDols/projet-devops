variable "cloud" {
  description = "Cloud provider: aws or azure"
  type        = string
  validation {
    condition     = contains(["aws", "azure"], var.cloud)
    error_message = "cloud must be either aws or azure."
  }
}

variable "name" {
  description = "Registry name"
  type        = string
}

variable "location" {
  description = "Azure location (only used when cloud = azure)"
  type        = string
  default     = ""
}

variable "resource_group_name" {
  description = "Azure resource group name (only used when cloud = azure)"
  type        = string
  default     = ""
}
