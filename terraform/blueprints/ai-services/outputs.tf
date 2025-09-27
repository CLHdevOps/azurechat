# AI Services Blueprint Outputs

# Azure AI Foundry (Machine Learning) Outputs
output "ai_foundry_workspace_id" {
  description = "Azure AI Foundry workspace ID"
  value       = azurerm_machine_learning_workspace.ai_foundry.id
}

output "ai_foundry_workspace_name" {
  description = "Azure AI Foundry workspace name"
  value       = azurerm_machine_learning_workspace.ai_foundry.name
}

output "ai_foundry_discovery_url" {
  description = "Azure AI Foundry discovery URL"
  value       = azurerm_machine_learning_workspace.ai_foundry.discovery_url
}

output "chat_endpoint_uri" {
  description = "AI Foundry chat endpoint URI"
  value       = jsondecode(azapi_resource.chat_endpoint.output).properties.scoringUri
  sensitive   = true
}

output "embeddings_endpoint_uri" {
  description = "AI Foundry embeddings endpoint URI"
  value       = jsondecode(azapi_resource.embeddings_endpoint.output).properties.scoringUri
  sensitive   = true
}

output "ai_foundry_endpoints" {
  description = "AI Foundry endpoint information"
  value = {
    chat_endpoint_name       = azapi_resource.chat_endpoint.name
    embeddings_endpoint_name = azapi_resource.embeddings_endpoint.name
    chat_deployment_name     = azapi_resource.chat_deployment.name
    embeddings_deployment_name = azapi_resource.embeddings_deployment.name
  }
}

# Legacy Azure OpenAI Outputs (for backward compatibility)
output "openai_id" {
  description = "Azure OpenAI service ID"
  value       = azurerm_cognitive_account.openai.id
}

output "openai_name" {
  description = "Azure OpenAI service name"
  value       = azurerm_cognitive_account.openai.name
}

output "openai_endpoint" {
  description = "Azure OpenAI service endpoint"
  value       = azurerm_cognitive_account.openai.endpoint
}

output "dalle_id" {
  description = "DALL-E service ID"
  value       = azurerm_cognitive_account.dalle.id
}

output "dalle_name" {
  description = "DALL-E service name"
  value       = azurerm_cognitive_account.dalle.name
}

output "dalle_endpoint" {
  description = "DALL-E service endpoint"
  value       = azurerm_cognitive_account.dalle.endpoint
}

output "search_service_id" {
  description = "Azure AI Search service ID"
  value       = azurerm_search_service.main.id
}

output "search_service_name" {
  description = "Azure AI Search service name"
  value       = azurerm_search_service.main.name
}

output "search_service_url" {
  description = "Azure AI Search service URL"
  value       = "https://${azurerm_search_service.main.name}.search.windows.net"
}

output "document_intelligence_id" {
  description = "Document Intelligence service ID"
  value       = azurerm_cognitive_account.document_intelligence.id
}

output "document_intelligence_name" {
  description = "Document Intelligence service name"
  value       = azurerm_cognitive_account.document_intelligence.name
}

output "document_intelligence_endpoint" {
  description = "Document Intelligence service endpoint"
  value       = azurerm_cognitive_account.document_intelligence.endpoint
}

output "speech_service_id" {
  description = "Speech service ID"
  value       = azurerm_cognitive_account.speech.id
}

output "speech_service_name" {
  description = "Speech service name"
  value       = azurerm_cognitive_account.speech.name
}

output "speech_service_endpoint" {
  description = "Speech service endpoint"
  value       = azurerm_cognitive_account.speech.endpoint
}

output "openai_deployments" {
  description = "OpenAI deployment names"
  value = {
    chat       = azurerm_cognitive_deployment.gpt4.name
    embeddings = azurerm_cognitive_deployment.embeddings.name
    dalle      = azurerm_cognitive_deployment.dalle.name
  }
}

output "key_vault_secret_names" {
  description = "Key Vault secret names for AI services"
  value = {
    # Azure OpenAI secrets
    openai_api_key                    = azurerm_key_vault_secret.openai_api_key.name
    dalle_api_key                    = azurerm_key_vault_secret.dalle_api_key.name
    
    # AI Foundry secrets
    ai_foundry_workspace_key         = azurerm_key_vault_secret.ai_foundry_workspace_key.name
    chat_endpoint_uri                = azurerm_key_vault_secret.chat_endpoint_uri.name
    embeddings_endpoint_uri          = azurerm_key_vault_secret.embeddings_endpoint_uri.name
    
    # Other AI services
    search_admin_key                 = azurerm_key_vault_secret.search_admin_key.name
    document_intelligence_api_key    = azurerm_key_vault_secret.document_intelligence_api_key.name
    speech_api_key                  = azurerm_key_vault_secret.speech_api_key.name
  }
}

output "private_endpoint_ids" {
  description = "Private endpoint IDs (if enabled)"
  value = var.enable_private_endpoints ? {
    ai_foundry            = azurerm_private_endpoint.ai_foundry[0].id
    openai                = azurerm_private_endpoint.openai[0].id
    dalle                 = azurerm_private_endpoint.dalle[0].id
    search                = azurerm_private_endpoint.search[0].id
    document_intelligence = azurerm_private_endpoint.document_intelligence[0].id
    speech                = azurerm_private_endpoint.speech[0].id
  } : {}
}

output "ai_foundry_managed_identities" {
  description = "AI Foundry managed identity IDs"
  value = {
    workspace_identity = azurerm_machine_learning_workspace.ai_foundry.identity[0].principal_id
    chat_endpoint_identity = jsondecode(azapi_resource.chat_endpoint.output).identity.principalId
    embeddings_endpoint_identity = jsondecode(azapi_resource.embeddings_endpoint.output).identity.principalId
  }
}