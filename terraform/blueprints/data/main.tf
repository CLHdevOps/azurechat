# Data Blueprint - Cosmos DB and Storage Account
# This blueprint creates data storage infrastructure for Azure Chat

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

# Cosmos DB Account
resource "azurerm_cosmosdb_account" "main" {
  name                = "cosmos-${var.application_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  # Consistency policy
  consistency_policy {
    consistency_level       = "BoundedStaleness"
    max_interval_in_seconds = 86400
    max_staleness_prefix    = 300000
  }

  # Geo-replication locations
  geo_location {
    location          = var.location
    failover_priority = 0
    zone_redundant    = var.environment == "prod" ? true : false
  }

  # Enable automatic failover for production
  enable_automatic_failover = var.environment == "prod" ? true : false

  # Network access
  public_network_access_enabled = var.enable_private_endpoints ? false : true
  
  dynamic "ip_range_filter" {
    for_each = var.enable_private_endpoints ? [] : ["0.0.0.0"]
    content {
      ip_range_filter = ip_range_filter.value
    }
  }

  # Capabilities
  capabilities {
    name = "EnableServerless"
  }

  # Backup policy
  backup {
    type                = "Periodic"
    interval_in_minutes = var.environment == "prod" ? 240 : 1440
    retention_in_hours  = var.environment == "prod" ? 720 : 168
    storage_redundancy  = var.environment == "prod" ? "Geo" : "Local"
  }

  # Identity for managed identity access
  identity {
    type = "SystemAssigned"
  }

  tags = merge(var.tags, {
    Component = "data"
    Purpose   = "document-database"
  })
}

# Cosmos DB Database
resource "azurerm_cosmosdb_sql_database" "main" {
  name                = var.cosmos_db_name
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
  
  # Use serverless throughput for cost optimization
  throughput = null

  tags = merge(var.tags, {
    Component = "data"
    Purpose   = "chat-database"
  })
}

# Chat History Container
resource "azurerm_cosmosdb_sql_container" "history" {
  name                   = var.cosmos_container_name
  resource_group_name    = var.resource_group_name
  account_name           = azurerm_cosmosdb_account.main.name
  database_name          = azurerm_cosmosdb_sql_database.main.name
  partition_key_path     = "/userId"
  partition_key_version  = 1
  throughput            = var.cosmos_throughput

  # Indexing policy for chat messages
  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }

    excluded_path {
      path = "/\"_etag\"/?"
    }

    # Composite indexes for efficient queries
    composite_index {
      index {
        path  = "/userId"
        order = "ascending"
      }
      index {
        path  = "/createdAt"
        order = "descending"
      }
    }

    composite_index {
      index {
        path  = "/threadId"
        order = "ascending"
      }
      index {
        path  = "/createdAt"
        order = "descending"
      }
    }
  }

  # Unique key constraint
  unique_key {
    paths = ["/id", "/userId"]
  }

  tags = merge(var.tags, {
    Component = "data"
    Purpose   = "chat-history"
  })
}

# Configuration Container
resource "azurerm_cosmosdb_sql_container" "config" {
  name                   = var.cosmos_config_container_name
  resource_group_name    = var.resource_group_name
  account_name           = azurerm_cosmosdb_account.main.name
  database_name          = azurerm_cosmosdb_sql_database.main.name
  partition_key_path     = "/type"
  partition_key_version  = 1
  throughput            = 400  # Fixed throughput for config data

  # Indexing policy for configuration data
  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }

    excluded_path {
      path = "/\"_etag\"/?"
    }
  }

  # Unique key for config items
  unique_key {
    paths = ["/id", "/type"]
  }

  tags = merge(var.tags, {
    Component = "data"
    Purpose   = "application-config"
  })
}

# Storage Account for blob storage
resource "azurerm_storage_account" "main" {
  name                     = "st${var.application_name}${var.environment}${random_string.storage_suffix.result}"
  resource_group_name      = var.resource_group_name
  location                = var.location
  account_tier            = var.storage_account_tier
  account_replication_type = var.storage_replication_type
  account_kind            = "StorageV2"

  # Security settings
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = var.enable_private_endpoints ? false : true

  # Blob properties
  blob_properties {
    # Enable versioning for production
    versioning_enabled = var.environment == "prod" ? true : false
    
    # Soft delete
    delete_retention_policy {
      days = var.environment == "prod" ? 30 : 7
    }
    
    container_delete_retention_policy {
      days = var.environment == "prod" ? 30 : 7
    }

    # CORS rules for web access
    cors_rule {
      allowed_headers    = ["*"]
      allowed_methods    = ["DELETE", "GET", "HEAD", "MERGE", "POST", "OPTIONS", "PUT", "PATCH"]
      allowed_origins    = ["https://${var.application_name}-${var.environment}.azurewebsites.net"]
      exposed_headers    = ["*"]
      max_age_in_seconds = 3600
    }
  }

  # Queue properties
  queue_properties {
    hour_metrics {
      enabled               = true
      include_apis          = true
      retention_policy_days = 7
      version               = "1.0"
    }
    
    minute_metrics {
      enabled               = true
      include_apis          = true
      retention_policy_days = 7
      version               = "1.0"
    }
  }

  # Network rules
  dynamic "network_rules" {
    for_each = var.enable_private_endpoints ? [1] : []
    content {
      default_action = "Deny"
      bypass         = ["AzureServices"]
      ip_rules       = []
      virtual_network_subnet_ids = []
    }
  }

  # Identity for managed identity access
  identity {
    type = "SystemAssigned"
  }

  tags = merge(var.tags, {
    Component = "data"
    Purpose   = "blob-storage"
  })
}

# Random string for storage account name uniqueness
resource "random_string" "storage_suffix" {
  length  = 4
  special = false
  upper   = false
}

# Blob container for documents
resource "azurerm_storage_container" "documents" {
  name                  = var.storage_container_name
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# Blob container for uploaded images
resource "azurerm_storage_container" "images" {
  name                  = "images"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# Store connection strings in Key Vault
resource "azurerm_key_vault_secret" "cosmos_primary_key" {
  name         = "cosmos-primary-key"
  value        = azurerm_cosmosdb_account.main.primary_key
  key_vault_id = var.key_vault_id

  tags = merge(var.tags, {
    Component = "data"
    Purpose   = "database-credentials"
  })
}

resource "azurerm_key_vault_secret" "storage_connection_string" {
  name         = "storage-connection-string"
  value        = azurerm_storage_account.main.primary_connection_string
  key_vault_id = var.key_vault_id

  tags = merge(var.tags, {
    Component = "data"
    Purpose   = "storage-credentials"
  })
}

resource "azurerm_key_vault_secret" "storage_account_key" {
  name         = "storage-account-key"
  value        = azurerm_storage_account.main.primary_access_key
  key_vault_id = var.key_vault_id

  tags = merge(var.tags, {
    Component = "data"
    Purpose   = "storage-credentials"
  })
}

# Private Endpoints (if enabled)
resource "azurerm_private_endpoint" "cosmos" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "pe-${var.application_name}-${var.environment}-cosmos"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoints_subnet_id

  private_service_connection {
    name                           = "psc-cosmos"
    private_connection_resource_id = azurerm_cosmosdb_account.main.id
    subresource_names              = ["Sql"]
    is_manual_connection           = false
  }

  tags = merge(var.tags, {
    Component = "data"
    Purpose   = "private-endpoint"
  })
}

resource "azurerm_private_endpoint" "storage" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "pe-${var.application_name}-${var.environment}-storage"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoints_subnet_id

  private_service_connection {
    name                           = "psc-storage"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  tags = merge(var.tags, {
    Component = "data"
    Purpose   = "private-endpoint"
  })
}

# Private DNS Records (if private endpoints are enabled)
resource "azurerm_private_dns_a_record" "cosmos" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = azurerm_cosmosdb_account.main.name
  zone_name           = "privatelink.documents.azure.com"
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.cosmos[0].private_service_connection[0].private_ip_address]

  tags = merge(var.tags, {
    Component = "data"
    Purpose   = "private-dns"
  })
}

resource "azurerm_private_dns_a_record" "storage" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = azurerm_storage_account.main.name
  zone_name           = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.storage[0].private_service_connection[0].private_ip_address]

  tags = merge(var.tags, {
    Component = "data"
    Purpose   = "private-dns"
  })
}

# Diagnostic settings for data services
resource "azurerm_monitor_diagnostic_setting" "cosmos" {
  name               = "diag-${azurerm_cosmosdb_account.main.name}"
  target_resource_id = azurerm_cosmosdb_account.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "DataPlaneRequests"
  }

  enabled_log {
    category = "QueryRuntimeStatistics"
  }

  enabled_log {
    category = "PartitionKeyStatistics"
  }

  enabled_log {
    category = "PartitionKeyRUConsumption"
  }

  metric {
    category = "Requests"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "storage" {
  name               = "diag-${azurerm_storage_account.main.name}"
  target_resource_id = "${azurerm_storage_account.main.id}/blobServices/default"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "Transaction"
    enabled  = true
  }

  metric {
    category = "Capacity"
    enabled  = true
  }
}