# Azure DevOps CI/CD Pipeline Setup Guide

This guide provides comprehensive instructions for setting up the Azure DevOps CI/CD pipeline for the Azure Chat application.

## Prerequisites

- Azure DevOps organization with appropriate permissions
- Azure subscription with Contributor access
- Service connections configured for Dev and Production environments
- Azure CLI installed for local testing

## Pipeline Architecture

The pipeline implements enterprise DevOps practices with:
- **Multi-stage deployment** (Dev → Prod)
- **Infrastructure as Code** using Bicep templates
- **Security scanning** and vulnerability assessment
- **Blue-green deployment** with staging slots
- **Automated rollback** capabilities
- **Health checks** and monitoring

## Required Service Connections

Create the following Azure Resource Manager service connections in Azure DevOps:

### Development Environment
- **Name**: `azure-connection-dev`
- **Type**: Azure Resource Manager
- **Authentication**: Managed Identity (recommended) or Service Principal
- **Scope**: Subscription or Resource Group
- **Permissions**: Contributor role on target subscription/resource group

### Production Environment
- **Name**: `azure-connection-prod`
- **Type**: Azure Resource Manager
- **Authentication**: Managed Identity (recommended) or Service Principal
- **Scope**: Subscription or Resource Group
- **Permissions**: Contributor role on target subscription/resource group

## Variable Groups Configuration

### 1. Shared Variables (`azurechat-shared`)

Create this variable group in Azure DevOps Library with common settings:

```yaml
Variables:
  # Build Configuration
  AZURE_LOCATION: "East US"
  OPENAI_LOCATION: "eastus"
  DALLE_LOCATION: "eastus"
  
  # Application Configuration
  COSMOS_DB_NAME: "chat"
  COSMOS_CONTAINER_NAME: "history"
  COSMOS_CONFIG_CONTAINER_NAME: "config"
  SEARCH_INDEX_NAME: "azure-chat"
  OPENAI_DEPLOYMENT_NAME: "gpt-4o"
  OPENAI_API_VERSION: "2024-08-01-preview"
  OPENAI_EMBEDDINGS_DEPLOYMENT_NAME: "embedding"
  OPENAI_DALLE_DEPLOYMENT_NAME: "dall-e-3"
  OPENAI_DALLE_API_VERSION: "2023-12-01-preview"
  SPEECH_REGION: "eastus"
```

### 2. Development Variables (`azurechat-dev`)

```yaml
Variables:
  # Infrastructure Names (Dev)
  ENVIRONMENT_NAME: "azurechat-dev"
  WEBAPP_NAME_DEV: "azurechat-dev-webapp"
  KEY_VAULT_NAME_DEV: "azurechat-dev-kv"
  OPENAI_INSTANCE_NAME_DEV: "azurechat-dev-openai"
  OPENAI_DALLE_INSTANCE_NAME_DEV: "azurechat-dev-dalle"
  SEARCH_SERVICE_NAME_DEV: "azurechat-dev-search"
  STORAGE_ACCOUNT_NAME_DEV: "azurechatdevstorage"
  DOCUMENT_INTELLIGENCE_ENDPOINT_DEV: "https://azurechat-dev-docint.cognitiveservices.azure.com/"
  
  # Application Settings (Dev)
  ADMIN_EMAIL_ADDRESS_DEV: "dev@yourcompany.com"
  USE_PRIVATE_ENDPOINTS: "false"

# Secure Variables (stored in Azure Key Vault)
Secure Variables:
  - nextauth-secret: "[Generated 32-character random string]"
  - cosmos-uri: "[Auto-populated from infrastructure deployment]"
```

### 3. Production Variables (`azurechat-prod`)

```yaml
Variables:
  # Infrastructure Names (Prod)
  ENVIRONMENT_NAME: "azurechat-prod"
  WEBAPP_NAME_PROD: "azurechat-prod-webapp"
  KEY_VAULT_NAME_PROD: "azurechat-prod-kv"
  OPENAI_INSTANCE_NAME_PROD: "azurechat-prod-openai"
  OPENAI_DALLE_INSTANCE_NAME_PROD: "azurechat-prod-dalle"
  SEARCH_SERVICE_NAME_PROD: "azurechat-prod-search"
  STORAGE_ACCOUNT_NAME_PROD: "azurechatprodstorage"
  DOCUMENT_INTELLIGENCE_ENDPOINT_PROD: "https://azurechat-prod-docint.cognitiveservices.azure.com/"
  
  # Application Settings (Prod)
  ADMIN_EMAIL_ADDRESS_PROD: "admin@yourcompany.com"
  USE_PRIVATE_ENDPOINTS: "true"

# Secure Variables (stored in Azure Key Vault)
Secure Variables:
  - nextauth-secret: "[Generated 32-character random string]"
  - cosmos-uri: "[Auto-populated from infrastructure deployment]"
```

## Environment Configuration

### 1. Create Environments in Azure DevOps

#### Development Environment
- **Name**: `azurechat-dev`
- **Resource**: None (serverless deployment)
- **Security**: No approval required
- **Checks**: Basic deployment validation

#### Production Environment
- **Name**: `azurechat-prod`
- **Resource**: None (serverless deployment)
- **Security**: 
  - **Manual Approval**: Required (specify approvers)
  - **Branch Protection**: Only allow `main` branch
  - **Business Hours**: Optional deployment window
- **Checks**: 
  - Security and compliance validation
  - Change management approval

### 2. Environment Security Configuration

#### Development Environment Permissions
- **Pipeline Deployment**: All team members
- **Approval**: Not required
- **Branch Policies**: Allow `develop` and `main` branches

#### Production Environment Permissions
- **Pipeline Deployment**: DevOps engineers and release managers only
- **Approval**: Required from at least 2 senior team members
- **Branch Policies**: Only `main` branch allowed
- **Change Management**: Integration with ServiceNow/JIRA (optional)

## Key Vault Configuration

### Development Key Vault Setup
```bash
# Create Key Vault for development
az keyvault create \
  --name "azurechat-dev-kv" \
  --resource-group "rg-azurechat-dev" \
  --location "East US" \
  --enable-rbac-authorization true

# Grant pipeline access (using service principal)
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee "<pipeline-service-principal-id>" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/rg-azurechat-dev/providers/Microsoft.KeyVault/vaults/azurechat-dev-kv"
```

### Production Key Vault Setup
```bash
# Create Key Vault for production
az keyvault create \
  --name "azurechat-prod-kv" \
  --resource-group "rg-azurechat-prod" \
  --location "East US" \
  --enable-rbac-authorization true \
  --network-acls-default-action Deny

# Grant pipeline access (using service principal)
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee "<pipeline-service-principal-id>" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/rg-azurechat-prod/providers/Microsoft.KeyVault/vaults/azurechat-prod-kv"
```

### Required Secrets in Key Vault

Both Key Vaults should contain these secrets:

```bash
# NextAuth secret (generate a secure random string)
az keyvault secret set \
  --vault-name "azurechat-dev-kv" \
  --name "nextauth-secret" \
  --value "$(openssl rand -base64 32)"

# Additional secrets will be populated by infrastructure deployment:
# - cosmos-uri: Cosmos DB connection string
# - storage-connection-string: Storage account connection string
# - openai-api-key: OpenAI service key (if not using managed identity)
```

## Pipeline Execution Flow

### 1. Continuous Integration (CI)
- **Triggered by**: Push to `main`, `develop`, or `release/*` branches
- **Code Quality**: ESLint, TypeScript compilation
- **Security Scanning**: npm audit, dependency analysis
- **Build**: Next.js application build
- **Artifacts**: Application package and infrastructure templates
- **Duration**: ~5-8 minutes

### 2. Development Deployment
- **Triggered by**: CI success on `develop` or `main` branch
- **Infrastructure**: Deploy/update Azure resources via Bicep
- **Application**: Deploy to Azure Web App
- **Validation**: Health checks and smoke tests
- **Duration**: ~10-15 minutes

### 3. Production Deployment
- **Triggered by**: Dev deployment success on `main` branch only
- **Approval Gate**: Manual approval required
- **Infrastructure**: Deploy/update Azure resources with production settings
- **Blue-Green Deployment**: Deploy to staging slot, validate, swap to production
- **Monitoring**: Post-deployment validation and alerts
- **Duration**: ~15-20 minutes (excluding approval time)

## Security Considerations

### 1. Secret Management
- ✅ All secrets stored in Azure Key Vault
- ✅ Pipeline uses managed identities where possible
- ✅ No hardcoded credentials in repository
- ✅ Least privilege access principles

### 2. Network Security
- ✅ Production uses private endpoints (configurable)
- ✅ Key Vault network access restrictions
- ✅ Web App network isolation options

### 3. Compliance
- ✅ Automated security scanning
- ✅ Vulnerability assessment
- ✅ Deployment audit trails
- ✅ Change management integration

## Monitoring and Alerting

### 1. Pipeline Monitoring
- Build success/failure notifications
- Deployment duration tracking
- Security scan results
- Performance metrics

### 2. Application Monitoring
- Application Insights integration
- Custom dashboards for key metrics
- Automated alerts for failures
- Health endpoint monitoring

## Rollback Strategy

### Automatic Rollback Triggers
- Health check failures after deployment
- Critical application errors within 15 minutes
- Performance degradation beyond thresholds

### Manual Rollback Process
```bash
# Swap back to previous deployment slot
az webapp deployment slot swap \
  --resource-group "rg-azurechat-prod" \
  --name "azurechat-prod-webapp" \
  --slot "production" \
  --target-slot "staging"
```

## Troubleshooting

### Common Issues

#### 1. Pipeline Failure: "Cannot find artifact"
- **Cause**: Build artifacts not published correctly
- **Solution**: Verify build job completed successfully and artifacts are published

#### 2. Deployment Failure: "Key Vault access denied"
- **Cause**: Service principal lacks Key Vault permissions
- **Solution**: Grant "Key Vault Secrets User" role to pipeline service principal

#### 3. Health Check Failure: "Application not responding"
- **Cause**: Application startup issues or configuration errors
- **Solution**: 
  - Check application logs in Azure Portal
  - Verify environment variables are correctly set
  - Ensure all Azure services are properly configured

#### 4. Infrastructure Deployment Failure: "Resource already exists"
- **Cause**: Bicep template trying to create existing resources
- **Solution**: Use incremental deployment mode and ensure template is idempotent

### Support Contacts
- **DevOps Team**: devops@yourcompany.com
- **Application Team**: azurechat-team@yourcompany.com
- **Security Team**: security@yourcompany.com

## Next Steps

1. **Set up service connections** in Azure DevOps
2. **Create variable groups** with environment-specific values
3. **Configure environments** with appropriate approvals
4. **Set up Key Vaults** and populate initial secrets
5. **Test pipeline** with a feature branch first
6. **Configure monitoring** and alerting
7. **Document runbooks** for operations team

This comprehensive setup ensures enterprise-grade security, reliability, and maintainability for your Azure Chat application deployment pipeline.