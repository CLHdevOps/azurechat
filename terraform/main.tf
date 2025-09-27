# Azure Chat Application - Terraform Root Module
# This is the main composition module that orchestrates all blueprints

terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.9"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Terraform Cloud Backend Configuration
  cloud {
    organization = var.terraform_cloud_organization
    workspaces {
      tags = ["azurechat", var.environment]
    }
  }
}

# Configure the Azure Provider
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  
  # Use managed identity for authentication in Azure DevOps
  use_msi = var.use_managed_identity
  
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
}

provider "azuread" {
  tenant_id = var.azure_tenant_id
}

# Data sources for current context
data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}

# Resource group for all resources
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.application_name}-${var.environment}"
  location = var.azure_location

  tags = merge(var.common_tags, {
    Environment = var.environment
    Application = var.application_name
    ManagedBy   = "terraform"
    Purpose     = "Azure Chat Application"
  })
}

# Network Blueprint
module "network" {
  source = "./blueprints/network"

  environment         = var.environment
  application_name    = var.application_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  # Network configuration
  vnet_address_space              = var.vnet_address_space
  private_endpoints_subnet_prefix = var.private_endpoints_subnet_prefix
  app_service_subnet_prefix       = var.app_service_subnet_prefix
  
  # Security settings
  enable_private_endpoints = var.enable_private_endpoints
  
  tags = var.common_tags

  depends_on = [azurerm_resource_group.main]
}

# Security Blueprint
module "security" {
  source = "./blueprints/security"

  environment         = var.environment
  application_name    = var.application_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  # Security configuration
  enable_private_endpoints = var.enable_private_endpoints
  tenant_id               = data.azurerm_client_config.current.tenant_id
  current_user_object_id  = data.azuread_client_config.current.object_id
  
  # Network integration
  private_endpoints_subnet_id = var.enable_private_endpoints ? module.network.private_endpoints_subnet_id : null
  
  # Admin configuration
  admin_email_addresses = var.admin_email_addresses
  
  tags = var.common_tags

  depends_on = [module.network]
}

# AI Services Blueprint
module "ai_services" {
  source = "./blueprints/ai-services"

  environment         = var.environment
  application_name    = var.application_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  # OpenAI configuration
  openai_location              = var.openai_location
  openai_sku                  = var.openai_sku
  dalle_location              = var.dalle_location
  chatgpt_deployment_capacity = var.chatgpt_deployment_capacity
  embedding_deployment_capacity = var.embedding_deployment_capacity
  dalle_deployment_capacity   = var.dalle_deployment_capacity
  
  # AI Search configuration
  search_service_sku = var.search_service_sku
  search_index_name  = var.search_index_name
  
  # Document Intelligence
  document_intelligence_sku = var.document_intelligence_sku
  
  # Speech Services
  speech_service_sku = var.speech_service_sku
  
  # Security integration
  key_vault_id                = module.security.key_vault_id
  enable_private_endpoints    = var.enable_private_endpoints
  private_endpoints_subnet_id = var.enable_private_endpoints ? module.network.private_endpoints_subnet_id : null
  
  tags = var.common_tags

  depends_on = [module.security]
}

# Data Blueprint
module "data" {
  source = "./blueprints/data"

  environment         = var.environment
  application_name    = var.application_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  # Cosmos DB configuration
  cosmos_db_name           = var.cosmos_db_name
  cosmos_container_name    = var.cosmos_container_name
  cosmos_config_container_name = var.cosmos_config_container_name
  cosmos_throughput        = var.cosmos_throughput
  
  # Storage configuration
  storage_account_tier        = var.storage_account_tier
  storage_replication_type   = var.storage_replication_type
  storage_container_name     = var.storage_container_name
  
  # Security integration
  key_vault_id                = module.security.key_vault_id
  enable_private_endpoints    = var.enable_private_endpoints
  private_endpoints_subnet_id = var.enable_private_endpoints ? module.network.private_endpoints_subnet_id : null
  
  tags = var.common_tags

  depends_on = [module.security]
}

# Application Blueprint
module "application" {
  source = "./blueprints/application"

  environment         = var.environment
  application_name    = var.application_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  # App Service configuration
  app_service_plan_sku        = var.app_service_plan_sku
  app_service_plan_os_type    = "Linux"
  node_version               = var.node_version
  
  # Network integration
  app_service_subnet_id = var.enable_private_endpoints ? module.network.app_service_subnet_id : null
  
  # Dependencies from other modules
  key_vault_id = module.security.key_vault_id
  
  # Application settings
  application_settings = {
    # Managed Identity
    USE_MANAGED_IDENTITIES = "true"
    
    # Database
    AZURE_COSMOSDB_URI           = module.data.cosmos_db_endpoint
    AZURE_COSMOSDB_DB_NAME       = var.cosmos_db_name
    AZURE_COSMOSDB_CONTAINER_NAME = var.cosmos_container_name
    AZURE_COSMOSDB_CONFIG_CONTAINER_NAME = var.cosmos_config_container_name
    
    # AI Services
    AZURE_OPENAI_API_INSTANCE_NAME = module.ai_services.openai_name
    AZURE_OPENAI_API_VERSION       = var.openai_api_version
    AZURE_OPENAI_API_DEPLOYMENT_NAME = var.openai_deployment_name
    AZURE_OPENAI_API_EMBEDDINGS_DEPLOYMENT_NAME = var.openai_embeddings_deployment_name
    AZURE_OPENAI_DALLE_API_INSTANCE_NAME = module.ai_services.dalle_name
    AZURE_OPENAI_DALLE_API_DEPLOYMENT_NAME = var.dalle_deployment_name
    AZURE_OPENAI_DALLE_API_VERSION = var.dalle_api_version
    
    # Search
    AZURE_SEARCH_NAME       = module.ai_services.search_service_name
    AZURE_SEARCH_INDEX_NAME = var.search_index_name
    
    # Document Intelligence
    AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT = module.ai_services.document_intelligence_endpoint
    
    # Speech
    AZURE_SPEECH_REGION = var.azure_location
    
    # Storage
    AZURE_STORAGE_ACCOUNT_NAME = module.data.storage_account_name
    
    # Security
    AZURE_KEY_VAULT_NAME = module.security.key_vault_name
    
    # Application
    NEXTAUTH_URL = "https://${var.application_name}-${var.environment}.azurewebsites.net"
    ADMIN_EMAIL_ADDRESS = join(",", var.admin_email_addresses)
    MAX_UPLOAD_DOCUMENT_SIZE = var.max_upload_document_size
    
    # Monitoring (if enabled)
    DD_SERVICE = var.application_name
    DD_ENV     = var.environment
    DD_SITE    = var.datadog_site
    
    # Feature flags
    DEBUG = var.environment == "dev" ? "true" : "false"
  }
  
  tags = var.common_tags

  depends_on = [module.ai_services, module.data, module.security]
}

# Monitoring Blueprint (Optional)
module "monitoring" {
  count  = var.enable_monitoring ? 1 : 0
  source = "./blueprints/monitoring"

  environment         = var.environment
  application_name    = var.application_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  # Application Insights configuration
  application_insights_type        = "web"
  workspace_id                    = null  # Create new workspace
  daily_data_cap_in_gb           = var.log_analytics_daily_cap
  daily_data_cap_notifications_disabled = false
  
  # Monitoring targets
  app_service_id = module.application.app_service_id
  
  # Alert configuration
  alert_email_addresses = var.admin_email_addresses
  
  tags = var.common_tags

  depends_on = [module.application]
}