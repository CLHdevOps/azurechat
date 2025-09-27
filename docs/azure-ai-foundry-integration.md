# Azure AI Foundry Integration Guide

## Overview

This document describes the integration of Azure AI Foundry (Azure Machine Learning) into the Azure Chat application infrastructure. Azure AI Foundry provides a unified platform for AI model deployment, management, and monitoring.

## Architecture Components

### Core AI Foundry Infrastructure

#### Azure Machine Learning Workspace
- **Name**: `aml-{application_name}-{environment}`
- **Purpose**: Central AI workspace for model deployment and management
- **Features**:
  - Model registration and versioning
  - Online endpoint management
  - Monitoring and logging
  - Private network access support

#### Supporting Services
- **Application Insights**: AI monitoring and telemetry
- **Container Registry**: Custom model container storage
- **Storage Account**: Workspace artifacts and data
- **Key Vault Integration**: Secure secret management

### AI Model Endpoints

#### Chat Endpoint
- **Endpoint Name**: `chat-endpoint-{environment}`
- **Model**: GPT-4 (latest version from Azure ML registry)
- **Deployment**: `chat-deployment-v1`
- **Instance Type**: 
  - Development: `Standard_DS2_v2`
  - Production: `Standard_DS3_v2`
- **Scaling**: Auto-scaling based on environment

#### Embeddings Endpoint
- **Endpoint Name**: `embeddings-endpoint-{environment}`
- **Model**: Text-Embedding-Ada-002 (latest version)
- **Deployment**: `embeddings-deployment-v1`
- **Instance Type**: 
  - Development: `Standard_DS2_v2`
  - Production: `Standard_DS3_v2`
- **Scaling**: Higher concurrency for embedding processing

## Configuration

### Environment Variables

The following environment variables are available in Key Vault:

```bash
# AI Foundry Workspace
AI_FOUNDRY_WORKSPACE_KEY="ai-foundry-workspace-key"
AI_FOUNDRY_WORKSPACE_NAME="aml-azurechat-{env}"

# Model Endpoints
AI_FOUNDRY_CHAT_ENDPOINT_URI="ai-foundry-chat-endpoint-uri"
AI_FOUNDRY_EMBEDDINGS_ENDPOINT_URI="ai-foundry-embeddings-endpoint-uri"

# Legacy OpenAI (maintained for backward compatibility)
AZURE_OPENAI_API_KEY="azure-openai-api-key"
AZURE_DALLE_API_KEY="azure-dalle-api-key"
```

### Application Integration

#### Using AI Foundry Endpoints

```typescript
// Example: Calling AI Foundry Chat Endpoint
const chatEndpointUri = process.env.AI_FOUNDRY_CHAT_ENDPOINT_URI;
const response = await fetch(`${chatEndpointUri}/score`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${authToken}`
  },
  body: JSON.stringify({
    input_data: {
      input_string: [
        {
          role: "user",
          content: "Hello, how can you help me?"
        }
      ]
    }
  })
});
```

#### Authentication Methods

1. **Managed Identity** (Recommended for production)
   - Automatic authentication using App Service managed identity
   - No credential management required

2. **Service Principal**
   - For development and testing environments
   - Requires client credentials

## Deployment Process

### Infrastructure Deployment

The AI Foundry infrastructure is deployed through Terraform:

```hcl
# AI Foundry Workspace
resource "azurerm_machine_learning_workspace" "ai_foundry" {
  name                          = "aml-${var.application_name}-${var.environment}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  application_insights_id       = azurerm_application_insights.ai_foundry.id
  key_vault_id                 = var.key_vault_id
  storage_account_id           = azurerm_storage_account.ai_foundry.id
  container_registry_id        = azurerm_container_registry.ai_foundry.id
}
```

### Model Deployment Pipeline

1. **Model Registration**: Models are sourced from Azure ML registry
2. **Endpoint Creation**: Online endpoints are created for real-time inference
3. **Deployment Configuration**: Resource allocation and scaling settings
4. **Traffic Routing**: 100% traffic directed to active deployment
5. **Health Monitoring**: Liveness and readiness probes configured

## Monitoring and Observability

### Application Insights Integration

- **Workspace Metrics**: Model performance, request latency, error rates
- **Custom Telemetry**: Business-specific AI metrics
- **Alerting**: Automated alerts on model performance degradation

### Key Metrics

- **Request Latency**: < 2000ms for chat endpoints
- **Throughput**: Requests per second capacity
- **Error Rate**: < 1% error rate target
- **Model Accuracy**: Custom accuracy metrics per model

## Security Configuration

### Network Security

- **Private Endpoints**: Secure connectivity for production environments
- **Virtual Network Integration**: Isolated network access
- **NSG Rules**: Restrict traffic to authorized sources only

### Access Control

- **RBAC**: Role-based access control for AI Foundry resources
- **Managed Identity**: Passwordless authentication
- **Key Vault Integration**: Secure secret and key management

### Compliance

- **Data Residency**: All data remains within specified Azure regions
- **Encryption**: Data encrypted at rest and in transit
- **Audit Logging**: Comprehensive audit trail for all AI operations

## Cost Management

### Resource Optimization

- **Environment-Based Scaling**: Different instance sizes per environment
- **Auto-Scaling**: Automatic scaling based on demand
- **Cost Monitoring**: Built-in cost tracking and alerting

### Estimated Monthly Costs

| Environment | Compute Cost | Storage Cost | Total Cost |
|-------------|--------------|--------------|------------|
| Development | $200-400     | $50-100      | $250-500   |
| Production  | $800-1500    | $100-200     | $900-1700  |

*Costs vary based on usage patterns and model complexity*

## Troubleshooting

### Common Issues

#### Endpoint Deployment Failures
```bash
# Check deployment status
az ml online-deployment show -n chat-deployment-v1 -e chat-endpoint-dev

# View deployment logs
az ml online-deployment get-logs -n chat-deployment-v1 -e chat-endpoint-dev
```

#### Authentication Errors
```bash
# Verify managed identity permissions
az role assignment list --assignee <managed-identity-id> --resource-group <rg-name>
```

#### Performance Issues
- Monitor Application Insights for latency metrics
- Check endpoint instance utilization
- Review model resource requirements

### Support Resources

- **Azure ML Documentation**: [docs.microsoft.com/azure/machine-learning](https://docs.microsoft.com/azure/machine-learning)
- **AI Foundry Portal**: [ml.azure.com](https://ml.azure.com)
- **Azure Support**: Create support ticket for infrastructure issues

## Migration from Legacy OpenAI

### Backward Compatibility

The infrastructure maintains backward compatibility with existing Azure OpenAI endpoints while introducing AI Foundry capabilities:

1. **Dual Endpoints**: Both legacy and AI Foundry endpoints available
2. **Gradual Migration**: Migrate individual features incrementally
3. **Feature Flags**: Toggle between legacy and AI Foundry endpoints
4. **Monitoring**: Compare performance across both platforms

### Migration Strategy

1. **Phase 1**: Deploy AI Foundry alongside existing infrastructure
2. **Phase 2**: Route test traffic to AI Foundry endpoints
3. **Phase 3**: Gradually shift production traffic
4. **Phase 4**: Deprecate legacy endpoints after validation

## Best Practices

### Development

- **Version Control**: All AI Foundry configurations in version control
- **Environment Parity**: Consistent configuration across environments
- **Testing**: Automated testing of model endpoints
- **Documentation**: Maintain up-to-date API documentation

### Operations

- **Monitoring**: Comprehensive monitoring and alerting
- **Backup**: Regular backup of model configurations
- **Disaster Recovery**: Cross-region failover capabilities
- **Updates**: Regular model and infrastructure updates

### Security

- **Least Privilege**: Minimal required permissions
- **Secret Rotation**: Regular rotation of keys and tokens
- **Network Isolation**: Private endpoints for production
- **Audit**: Regular security audits and compliance checks