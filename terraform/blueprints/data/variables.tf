# Data Blueprint Variables

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "application_name" {
  description = "Application name"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure location"
  type        = string
}

variable "cosmos_db_name" {
  description = "Cosmos DB database name"
  type        = string
  default     = "chat-db"
}

variable "cosmos_container_name" {
  description = "Cosmos DB container name for chat history"
  type        = string
  default     = "history"
}

variable "cosmos_config_container_name" {
  description = "Cosmos DB container name for configuration"
  type        = string
  default     = "config"
}

variable "cosmos_throughput" {
  description = "Cosmos DB throughput (RU/s)"
  type        = number
  default     = 400
  
  validation {
    condition     = var.cosmos_throughput >= 400
    error_message = "Cosmos DB throughput must be at least 400 RU/s."
  }
}

variable "storage_account_tier" {
  description = "Storage account performance tier"
  type        = string
  default     = "Standard"
  
  validation {
    condition     = contains(["Standard", "Premium"], var.storage_account_tier)
    error_message = "Storage account tier must be either Standard or Premium."
  }
}

variable "storage_replication_type" {
  description = "Storage account replication type"
  type        = string
  default     = "LRS"
  
  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.storage_replication_type)
    error_message = "Storage replication type must be a valid Azure storage replication type."
  }
}

variable "storage_container_name" {
  description = "Storage container name for documents"
  type        = string
  default     = "documents"
}

variable "key_vault_id" {
  description = "Key Vault ID for storing secrets"
  type        = string
}

variable "enable_private_endpoints" {
  description = "Enable private endpoints"
  type        = bool
  default     = false
}

variable "private_endpoints_subnet_id" {
  description = "Private endpoints subnet ID"
  type        = string
  default     = null
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for diagnostic settings"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}