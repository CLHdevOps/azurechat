# AI Services Blueprint - Azure AI Foundry (Machine Learning) with AI endpoints
# This blueprint creates Azure AI Foundry project with managed AI model endpoints

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.9"
    }
  }
}

# Data sources
data "azurerm_client_config" "current" {}

# Application Insights for AI Foundry
resource "azurerm_application_insights" "ai_foundry" {
  name                = "ai-${var.application_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
  workspace_id        = var.log_analytics_workspace_id

  tags = merge(var.tags, {
    Component = "ai-foundry"
    Purpose   = "ai-monitoring"
  })
}

# Container Registry for AI Foundry
resource "azurerm_container_registry" "ai_foundry" {
  name                = "cr${var.application_name}${var.environment}${random_string.acr_suffix.result}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false

  # Identity for managed identity access
  identity {
    type = "SystemAssigned"
  }

  tags = merge(var.tags, {
    Component = "ai-foundry"
    Purpose   = "container-registry"
  })
}

resource "random_string" "acr_suffix" {
  length  = 4
  special = false
  upper   = false
}

# Storage Account for AI Foundry workspace
resource "azurerm_storage_account" "ai_foundry" {
  name                     = "st${var.application_name}ai${var.environment}${random_string.ai_storage_suffix.result}"
  resource_group_name      = var.resource_group_name
  location                = var.location
  account_tier            = "Standard"
  account_replication_type = "LRS"
  account_kind            = "StorageV2"

  # Security settings
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = var.enable_private_endpoints ? false : true

  # Identity for managed identity access
  identity {
    type = "SystemAssigned"
  }

  tags = merge(var.tags, {
    Component = "ai-foundry"
    Purpose   = "ai-workspace-storage"
  })
}

resource "random_string" "ai_storage_suffix" {
  length  = 4
  special = false
  upper   = false
}

# Azure AI Foundry (Machine Learning) Workspace
resource "azurerm_machine_learning_workspace" "ai_foundry" {
  name                          = "aml-${var.application_name}-${var.environment}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  application_insights_id       = azurerm_application_insights.ai_foundry.id
  key_vault_id                 = var.key_vault_id
  storage_account_id           = azurerm_storage_account.ai_foundry.id
  container_registry_id        = azurerm_container_registry.ai_foundry.id

  # Network access
  public_network_access_enabled = var.enable_private_endpoints ? false : true

  # Identity for managed identity access
  identity {
    type = "SystemAssigned"
  }

  # High business impact for production
  high_business_impact = var.environment == "prod" ? true : false

  tags = merge(var.tags, {
    Component = "ai-foundry"
    Purpose   = "ai-workspace"
  })
}

# Azure OpenAI Service (still needed for cognitive services)
resource "azurerm_cognitive_account" "openai" {
  name                = "oai-${var.application_name}-${var.environment}"
  location            = var.openai_location
  resource_group_name = var.resource_group_name
  kind                = "OpenAI"
  sku_name            = var.openai_sku

  # Network restrictions
  public_network_access_enabled = var.enable_private_endpoints ? false : true
  
  dynamic "network_acls" {
    for_each = var.enable_private_endpoints ? [1] : []
    content {
      default_action = "Deny"
      ip_rules       = []
      virtual_network_rules = []
    }
  }

  tags = merge(var.tags, {
    Component = "ai-services"
    Purpose   = "openai-chat"
  })
}

# Connect OpenAI to AI Foundry workspace
resource "azapi_resource" "ai_foundry_openai_connection" {
  type      = "Microsoft.MachineLearningServices/workspaces/connections@2024-04-01"
  name      = "openai-connection"
  parent_id = azurerm_machine_learning_workspace.ai_foundry.id

  body = jsonencode({
    properties = {
      category    = "AzureOpenAI"
      target      = azurerm_cognitive_account.openai.endpoint
      authType    = "AAD"
      isSharedToAll = true
      metadata = {
        ApiType    = "Azure"
        ResourceId = azurerm_cognitive_account.openai.id
      }
    }
  })

  depends_on = [azurerm_machine_learning_workspace.ai_foundry]
}

# Azure OpenAI Deployments
resource "azurerm_cognitive_deployment" "gpt4" {
  name                 = var.chatgpt_deployment_name
  cognitive_account_id = azurerm_cognitive_account.openai.id
  
  model {
    format  = "OpenAI"
    name    = "gpt-4"
    version = "0613"
  }

  scale {
    type     = "Standard"
    capacity = var.chatgpt_deployment_capacity
  }
}

resource "azurerm_cognitive_deployment" "embeddings" {
  name                 = var.embedding_deployment_name
  cognitive_account_id = azurerm_cognitive_account.openai.id
  
  model {
    format  = "OpenAI"
    name    = "text-embedding-ada-002"
    version = "2"
  }

  scale {
    type     = "Standard"
    capacity = var.embedding_deployment_capacity
  }
}

# DALL-E Service (separate instance for DALL-E)
resource "azurerm_cognitive_account" "dalle" {
  name                = "dalle-${var.application_name}-${var.environment}"
  location            = var.dalle_location
  resource_group_name = var.resource_group_name
  kind                = "OpenAI"
  sku_name            = var.openai_sku

  public_network_access_enabled = var.enable_private_endpoints ? false : true
  
  dynamic "network_acls" {
    for_each = var.enable_private_endpoints ? [1] : []
    content {
      default_action = "Deny"
      ip_rules       = []
      virtual_network_rules = []
    }
  }

  tags = merge(var.tags, {
    Component = "ai-services"
    Purpose   = "dalle-image-generation"
  })
}

# Connect DALL-E to AI Foundry workspace
resource "azapi_resource" "ai_foundry_dalle_connection" {
  type      = "Microsoft.MachineLearningServices/workspaces/connections@2024-04-01"
  name      = "dalle-connection"
  parent_id = azurerm_machine_learning_workspace.ai_foundry.id

  body = jsonencode({
    properties = {
      category    = "AzureOpenAI"
      target      = azurerm_cognitive_account.dalle.endpoint
      authType    = "AAD"
      isSharedToAll = true
      metadata = {
        ApiType    = "Azure"
        ResourceId = azurerm_cognitive_account.dalle.id
      }
    }
  })

  depends_on = [azurerm_machine_learning_workspace.ai_foundry]
}

# DALL-E Deployment
resource "azurerm_cognitive_deployment" "dalle" {
  name                 = var.dalle_deployment_name
  cognitive_account_id = azurerm_cognitive_account.dalle.id
  
  model {
    format  = "OpenAI"
    name    = "dall-e-3"
    version = "3.0"
  }

  scale {
    type     = "Standard"
    capacity = var.dalle_deployment_capacity
  }
}

# AI Foundry Online Endpoint for Chat Model
resource "azapi_resource" "chat_endpoint" {
  type      = "Microsoft.MachineLearningServices/workspaces/onlineEndpoints@2024-04-01"
  name      = "chat-endpoint-${var.environment}"
  parent_id = azurerm_machine_learning_workspace.ai_foundry.id
  location  = var.location

  body = jsonencode({
    properties = {
      description = "Chat model endpoint for ${var.application_name}"
      authMode    = "AMLToken"
      publicNetworkAccess = var.enable_private_endpoints ? "Disabled" : "Enabled"
    }
    identity = {
      type = "SystemAssigned"
    }
  })

  tags = merge(var.tags, {
    Component = "ai-foundry"
    Purpose   = "chat-endpoint"
  })
}

# AI Foundry Online Endpoint for Embeddings Model
resource "azapi_resource" "embeddings_endpoint" {
  type      = "Microsoft.MachineLearningServices/workspaces/onlineEndpoints@2024-04-01"
  name      = "embeddings-endpoint-${var.environment}"
  parent_id = azurerm_machine_learning_workspace.ai_foundry.id
  location  = var.location

  body = jsonencode({
    properties = {
      description = "Embeddings model endpoint for ${var.application_name}"
      authMode    = "AMLToken"
      publicNetworkAccess = var.enable_private_endpoints ? "Disabled" : "Enabled"
    }
    identity = {
      type = "SystemAssigned"
    }
  })

  tags = merge(var.tags, {
    Component = "ai-foundry"
    Purpose   = "embeddings-endpoint"
  })
}

# AI Foundry Online Deployment for Chat Model
resource "azapi_resource" "chat_deployment" {
  type      = "Microsoft.MachineLearningServices/workspaces/onlineEndpoints/deployments@2024-04-01"
  name      = "chat-deployment-v1"
  parent_id = azapi_resource.chat_endpoint.id

  body = jsonencode({
    properties = {
      description = "GPT-4 chat deployment"
      model = {
        referenceType = "Model"
        assetId = "azureml://registries/azureml/models/gpt-4/versions/latest"
      }
      instanceType = var.environment == "prod" ? "Standard_DS3_v2" : "Standard_DS2_v2"
      instanceCount = var.environment == "prod" ? 2 : 1
      requestSettings = {
        requestTimeoutMs = 90000
        maxConcurrentRequestsPerInstance = 1
      }
      livenessProbe = {
        failureThreshold = 30
        successThreshold = 1
        periodSeconds = 10
        initialDelaySeconds = 10
      }
      readinessProbe = {
        failureThreshold = 10
        successThreshold = 1
        periodSeconds = 10
        initialDelaySeconds = 10
      }
    }
  })

  depends_on = [azapi_resource.chat_endpoint]
}

# AI Foundry Online Deployment for Embeddings Model
resource "azapi_resource" "embeddings_deployment" {
  type      = "Microsoft.MachineLearningServices/workspaces/onlineEndpoints/deployments@2024-04-01"
  name      = "embeddings-deployment-v1"
  parent_id = azapi_resource.embeddings_endpoint.id

  body = jsonencode({
    properties = {
      description = "Text embedding Ada 002 deployment"
      model = {
        referenceType = "Model"
        assetId = "azureml://registries/azureml/models/text-embedding-ada-002/versions/latest"
      }
      instanceType = var.environment == "prod" ? "Standard_DS3_v2" : "Standard_DS2_v2"
      instanceCount = var.environment == "prod" ? 2 : 1
      requestSettings = {
        requestTimeoutMs = 60000
        maxConcurrentRequestsPerInstance = 2
      }
      livenessProbe = {
        failureThreshold = 30
        successThreshold = 1
        periodSeconds = 10
        initialDelaySeconds = 10
      }
      readinessProbe = {
        failureThreshold = 10
        successThreshold = 1
        periodSeconds = 10
        initialDelaySeconds = 10
      }
    }
  })

  depends_on = [azapi_resource.embeddings_endpoint]
}

# Set endpoint traffic to 100% for the deployments
resource "azapi_update_resource" "chat_endpoint_traffic" {
  type      = "Microsoft.MachineLearningServices/workspaces/onlineEndpoints@2024-04-01"
  resource_id = azapi_resource.chat_endpoint.id

  body = jsonencode({
    properties = {
      traffic = {
        "chat-deployment-v1" = 100
      }
    }
  })

  depends_on = [azapi_resource.chat_deployment]
}

resource "azapi_update_resource" "embeddings_endpoint_traffic" {
  type      = "Microsoft.MachineLearningServices/workspaces/onlineEndpoints@2024-04-01"
  resource_id = azapi_resource.embeddings_endpoint.id

  body = jsonencode({
    properties = {
      traffic = {
        "embeddings-deployment-v1" = 100
      }
    }
  })

  depends_on = [azapi_resource.embeddings_deployment]
}

# Azure AI Search Service
resource "azurerm_search_service" "main" {
  name                = "search-${var.application_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.search_service_sku

  # Search service configuration
  replica_count                     = 1
  partition_count                   = 1
  public_network_access_enabled     = var.enable_private_endpoints ? false : true
  allowed_ips                      = []
  authentication_failure_mode       = "http403"
  customer_managed_key_enforcement_enabled = false

  # Identity for accessing other services
  identity {
    type = "SystemAssigned"
  }

  tags = merge(var.tags, {
    Component = "ai-services"
    Purpose   = "vector-search"
  })
}

# Document Intelligence Service
resource "azurerm_cognitive_account" "document_intelligence" {
  name                = "di-${var.application_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "FormRecognizer"
  sku_name            = var.document_intelligence_sku

  public_network_access_enabled = var.enable_private_endpoints ? false : true
  
  dynamic "network_acls" {
    for_each = var.enable_private_endpoints ? [1] : []
    content {
      default_action = "Deny"
      ip_rules       = []
      virtual_network_rules = []
    }
  }

  tags = merge(var.tags, {
    Component = "ai-services"
    Purpose   = "document-processing"
  })
}

# Speech Service
resource "azurerm_cognitive_account" "speech" {
  name                = "speech-${var.application_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "SpeechServices"
  sku_name            = var.speech_service_sku

  public_network_access_enabled = var.enable_private_endpoints ? false : true
  
  dynamic "network_acls" {
    for_each = var.enable_private_endpoints ? [1] : []
    content {
      default_action = "Deny"
      ip_rules       = []
      virtual_network_rules = []
    }
  }

  tags = merge(var.tags, {
    Component = "ai-services"
    Purpose   = "speech-to-text-text-to-speech"
  })
}

# Store API keys and AI Foundry endpoints in Key Vault
resource "azurerm_key_vault_secret" "openai_api_key" {
  name         = "azure-openai-api-key"
  value        = azurerm_cognitive_account.openai.primary_access_key
  key_vault_id = var.key_vault_id

  tags = merge(var.tags, {
    Component = "ai-services"
    Purpose   = "api-credentials"
  })
}

resource "azurerm_key_vault_secret" "dalle_api_key" {
  name         = "azure-dalle-api-key"
  value        = azurerm_cognitive_account.dalle.primary_access_key
  key_vault_id = var.key_vault_id

  tags = merge(var.tags, {
    Component = "ai-services"
    Purpose   = "api-credentials"
  })
}

resource "azurerm_key_vault_secret" "ai_foundry_workspace_key" {
  name         = "ai-foundry-workspace-key"
  value        = azurerm_machine_learning_workspace.ai_foundry.primary_user_assigned_identity[0].client_id
  key_vault_id = var.key_vault_id

  tags = merge(var.tags, {
    Component = "ai-foundry"
    Purpose   = "workspace-credentials"
  })
}

resource "azurerm_key_vault_secret" "chat_endpoint_uri" {
  name         = "ai-foundry-chat-endpoint-uri"
  value        = jsondecode(azapi_resource.chat_endpoint.output).properties.scoringUri
  key_vault_id = var.key_vault_id

  tags = merge(var.tags, {
    Component = "ai-foundry"
    Purpose   = "endpoint-uri"
  })

  depends_on = [azapi_resource.chat_endpoint]
}

resource "azurerm_key_vault_secret" "embeddings_endpoint_uri" {
  name         = "ai-foundry-embeddings-endpoint-uri"
  value        = jsondecode(azapi_resource.embeddings_endpoint.output).properties.scoringUri
  key_vault_id = var.key_vault_id

  tags = merge(var.tags, {
    Component = "ai-foundry"
    Purpose   = "endpoint-uri"
  })

  depends_on = [azapi_resource.embeddings_endpoint]
}

resource "azurerm_key_vault_secret" "search_admin_key" {
  name         = "azure-search-admin-key"
  value        = azurerm_search_service.main.primary_key
  key_vault_id = var.key_vault_id

  tags = merge(var.tags, {
    Component = "ai-services"
    Purpose   = "api-credentials"
  })
}

resource "azurerm_key_vault_secret" "document_intelligence_api_key" {
  name         = "azure-document-intelligence-api-key"
  value        = azurerm_cognitive_account.document_intelligence.primary_access_key
  key_vault_id = var.key_vault_id

  tags = merge(var.tags, {
    Component = "ai-services"
    Purpose   = "api-credentials"
  })
}

resource "azurerm_key_vault_secret" "speech_api_key" {
  name         = "azure-speech-api-key"
  value        = azurerm_cognitive_account.speech.primary_access_key
  key_vault_id = var.key_vault_id

  tags = merge(var.tags, {
    Component = "ai-services"
    Purpose   = "api-credentials"
  })
}

# Private Endpoints (if enabled)
resource "azurerm_private_endpoint" "ai_foundry" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "pe-${var.application_name}-${var.environment}-ai-foundry"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoints_subnet_id

  private_service_connection {
    name                           = "psc-ai-foundry"
    private_connection_resource_id = azurerm_machine_learning_workspace.ai_foundry.id
    subresource_names              = ["amlworkspace"]
    is_manual_connection           = false
  }

  tags = merge(var.tags, {
    Component = "ai-foundry"
    Purpose   = "private-endpoint"
  })
}

resource "azurerm_private_endpoint" "openai" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "pe-${var.application_name}-${var.environment}-openai"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoints_subnet_id

  private_service_connection {
    name                           = "psc-openai"
    private_connection_resource_id = azurerm_cognitive_account.openai.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  tags = merge(var.tags, {
    Component = "ai-services"
    Purpose   = "private-endpoint"
  })
}

resource "azurerm_private_endpoint" "dalle" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "pe-${var.application_name}-${var.environment}-dalle"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoints_subnet_id

  private_service_connection {
    name                           = "psc-dalle"
    private_connection_resource_id = azurerm_cognitive_account.dalle.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  tags = merge(var.tags, {
    Component = "ai-services"
    Purpose   = "private-endpoint"
  })
}

resource "azurerm_private_endpoint" "search" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "pe-${var.application_name}-${var.environment}-search"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoints_subnet_id

  private_service_connection {
    name                           = "psc-search"
    private_connection_resource_id = azurerm_search_service.main.id
    subresource_names              = ["searchService"]
    is_manual_connection           = false
  }

  tags = merge(var.tags, {
    Component = "ai-services"
    Purpose   = "private-endpoint"
  })
}

resource "azurerm_private_endpoint" "document_intelligence" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "pe-${var.application_name}-${var.environment}-di"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoints_subnet_id

  private_service_connection {
    name                           = "psc-document-intelligence"
    private_connection_resource_id = azurerm_cognitive_account.document_intelligence.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  tags = merge(var.tags, {
    Component = "ai-services"
    Purpose   = "private-endpoint"
  })
}

resource "azurerm_private_endpoint" "speech" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "pe-${var.application_name}-${var.environment}-speech"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoints_subnet_id

  private_service_connection {
    name                           = "psc-speech"
    private_connection_resource_id = azurerm_cognitive_account.speech.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  tags = merge(var.tags, {
    Component = "ai-services"
    Purpose   = "private-endpoint"
  })
}

# Private DNS Records (if private endpoints are enabled)
resource "azurerm_private_dns_a_record" "openai" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = azurerm_cognitive_account.openai.name
  zone_name           = "privatelink.openai.azure.com"
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.openai[0].private_service_connection[0].private_ip_address]

  tags = merge(var.tags, {
    Component = "ai-services"
    Purpose   = "private-dns"
  })
}

resource "azurerm_private_dns_a_record" "dalle" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = azurerm_cognitive_account.dalle.name
  zone_name           = "privatelink.openai.azure.com"
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.dalle[0].private_service_connection[0].private_ip_address]

  tags = merge(var.tags, {
    Component = "ai-services"
    Purpose   = "private-dns"
  })
}

resource "azurerm_private_dns_a_record" "search" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = azurerm_search_service.main.name
  zone_name           = "privatelink.search.windows.net"
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.search[0].private_service_connection[0].private_ip_address]

  tags = merge(var.tags, {
    Component = "ai-services"
    Purpose   = "private-dns"
  })
}

resource "azurerm_private_dns_a_record" "document_intelligence" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = azurerm_cognitive_account.document_intelligence.name
  zone_name           = "privatelink.cognitiveservices.azure.com"
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.document_intelligence[0].private_service_connection[0].private_ip_address]

  tags = merge(var.tags, {
    Component = "ai-services"
    Purpose   = "private-dns"
  })
}

resource "azurerm_private_dns_a_record" "speech" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = azurerm_cognitive_account.speech.name
  zone_name           = "privatelink.cognitiveservices.azure.com"
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.speech[0].private_service_connection[0].private_ip_address]

  tags = merge(var.tags, {
    Component = "ai-services"
    Purpose   = "private-dns"
  })
}

# Diagnostic settings for AI services
resource "azurerm_monitor_diagnostic_setting" "openai" {
  name               = "diag-${azurerm_cognitive_account.openai.name}"
  target_resource_id = azurerm_cognitive_account.openai.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "Audit"
  }

  enabled_log {
    category = "RequestResponse"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "search" {
  name               = "diag-${azurerm_search_service.main.name}"
  target_resource_id = azurerm_search_service.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "OperationLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}