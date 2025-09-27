# AI Services Blueprint Variables

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

variable "openai_location" {
  description = "Azure OpenAI service location"
  type        = string
}

variable "openai_sku" {
  description = "Azure OpenAI service SKU"
  type        = string
  default     = "S0"
}

variable "dalle_location" {
  description = "DALL-E service location"
  type        = string
}

variable "chatgpt_deployment_name" {
  description = "Name of the ChatGPT deployment"
  type        = string
  default     = "gpt-4"
}

variable "embedding_deployment_name" {
  description = "Name of the embedding deployment"
  type        = string
  default     = "text-embedding-ada-002"
}

variable "dalle_deployment_name" {
  description = "Name of the DALL-E deployment"
  type        = string
  default     = "dall-e-3"
}

variable "chatgpt_deployment_capacity" {
  description = "Capacity for ChatGPT deployment"
  type        = number
  default     = 10
}

variable "embedding_deployment_capacity" {
  description = "Capacity for embedding deployment"
  type        = number
  default     = 10
}

variable "dalle_deployment_capacity" {
  description = "Capacity for DALL-E deployment"
  type        = number
  default     = 1
}

variable "search_service_sku" {
  description = "SKU for Azure AI Search service"
  type        = string
  default     = "basic"
}

variable "search_index_name" {
  description = "Name of the search index"
  type        = string
  default     = "vector-search"
}

variable "document_intelligence_sku" {
  description = "SKU for Document Intelligence service"
  type        = string
  default     = "S0"
}

variable "speech_service_sku" {
  description = "SKU for Speech service"
  type        = string
  default     = "S0"
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