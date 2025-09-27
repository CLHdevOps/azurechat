# Data Blueprint Outputs

output "cosmos_db_account_id" {
  description = "Cosmos DB account ID"
  value       = azurerm_cosmosdb_account.main.id
}

output "cosmos_db_account_name" {
  description = "Cosmos DB account name"
  value       = azurerm_cosmosdb_account.main.name
}

output "cosmos_db_endpoint" {
  description = "Cosmos DB endpoint"
  value       = azurerm_cosmosdb_account.main.endpoint
}

output "cosmos_db_database_name" {
  description = "Cosmos DB database name"
  value       = azurerm_cosmosdb_sql_database.main.name
}

output "cosmos_container_names" {
  description = "Cosmos DB container names"
  value = {
    history = azurerm_cosmosdb_sql_container.history.name
    config  = azurerm_cosmosdb_sql_container.config.name
  }
}

output "storage_account_id" {
  description = "Storage account ID"
  value       = azurerm_storage_account.main.id
}

output "storage_account_name" {
  description = "Storage account name"
  value       = azurerm_storage_account.main.name
}

output "storage_account_primary_endpoint" {
  description = "Storage account primary blob endpoint"
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

output "storage_container_names" {
  description = "Storage container names"
  value = {
    documents = azurerm_storage_container.documents.name
    images    = azurerm_storage_container.images.name
  }
}

output "key_vault_secret_names" {
  description = "Key Vault secret names for data services"
  value = {
    cosmos_primary_key        = azurerm_key_vault_secret.cosmos_primary_key.name
    storage_connection_string = azurerm_key_vault_secret.storage_connection_string.name
    storage_account_key      = azurerm_key_vault_secret.storage_account_key.name
  }
}

output "cosmos_db_connection_strings" {
  description = "Cosmos DB connection strings"
  value = {
    primary   = azurerm_cosmosdb_account.main.connection_strings[0]
    secondary = length(azurerm_cosmosdb_account.main.connection_strings) > 1 ? azurerm_cosmosdb_account.main.connection_strings[1] : null
  }
  sensitive = true
}

output "private_endpoint_ids" {
  description = "Private endpoint IDs (if enabled)"
  value = var.enable_private_endpoints ? {
    cosmos  = azurerm_private_endpoint.cosmos[0].id
    storage = azurerm_private_endpoint.storage[0].id
  } : {}
}

output "managed_identity_ids" {
  description = "Managed identity IDs for data services"
  value = {
    cosmos_db_identity = azurerm_cosmosdb_account.main.identity[0].principal_id
    storage_identity   = azurerm_storage_account.main.identity[0].principal_id
  }
}