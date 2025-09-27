# Azure DevOps Setup Script for Azure Chat CI/CD Pipeline
# This script automates the creation of variable groups, environments, and service connections

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Organization,
    
    [Parameter(Mandatory = $true)]
    [string]$Project,
    
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $true)]
    [string]$TenantId,
    
    [Parameter(Mandatory = $false)]
    [string]$DevResourceGroup = "rg-azurechat-dev",
    
    [Parameter(Mandatory = $false)]
    [string]$ProdResourceGroup = "rg-azurechat-prod",
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "East US"
)

# Install Azure DevOps CLI extension if not already installed
Write-Host "🔧 Setting up Azure DevOps CLI extension..."
az extension add --name azure-devops --only-show-errors

# Set Azure DevOps defaults
az devops configure --defaults organization="https://dev.azure.com/$Organization" project="$Project"

# Login check
Write-Host "🔐 Checking Azure login status..."
$loginStatus = az account show --query "id" -o tsv 2>$null
if (-not $loginStatus) {
    Write-Host "Please login to Azure CLI first: az login"
    exit 1
}

Write-Host "✅ Azure CLI authenticated successfully"

# Function to create variable group
function New-VariableGroup {
    param($GroupName, $Description, $Variables)
    
    Write-Host "📋 Creating variable group: $GroupName"
    
    # Check if variable group exists
    $existingGroup = az pipelines variable-group list --group-name $GroupName --query "[0].id" -o tsv 2>$null
    
    if ($existingGroup) {
        Write-Host "⚠️ Variable group '$GroupName' already exists. Updating..."
        $groupId = $existingGroup
    } else {
        # Create new variable group
        $groupResult = az pipelines variable-group create --name $GroupName --description $Description --variables @{} --output json | ConvertFrom-Json
        $groupId = $groupResult.id
        Write-Host "✅ Created variable group '$GroupName' with ID: $groupId"
    }
    
    # Add/update variables
    foreach ($var in $Variables.GetEnumerator()) {
        Write-Host "  Adding variable: $($var.Key)"
        az pipelines variable-group variable create --group-id $groupId --name $var.Key --value $var.Value --only-show-errors
    }
    
    return $groupId
}

# Function to create environment
function New-Environment {
    param($EnvName, $Description)
    
    Write-Host "🌍 Creating environment: $EnvName"
    
    # Check if environment exists
    $existingEnv = az pipelines environment list --query "[?name=='$EnvName'].id" -o tsv 2>$null
    
    if ($existingEnv) {
        Write-Host "⚠️ Environment '$EnvName' already exists"
        return $existingEnv
    } else {
        $envResult = az pipelines environment create --name $EnvName --description $Description --output json | ConvertFrom-Json
        Write-Host "✅ Created environment '$EnvName' with ID: $($envResult.id)"
        return $envResult.id
    }
}

try {
    Write-Host "🚀 Starting Azure DevOps setup for Azure Chat application"
    Write-Host "Organization: $Organization"
    Write-Host "Project: $Project"
    Write-Host "Subscription: $SubscriptionId"
    Write-Host ""

    # Create shared variable group
    Write-Host "📋 Setting up shared variable group..."
    $sharedVariables = @{
        'AZURE_LOCATION' = $Location
        'OPENAI_LOCATION' = 'eastus'
        'DALLE_LOCATION' = 'eastus'
        'COSMOS_DB_NAME' = 'chat'
        'COSMOS_CONTAINER_NAME' = 'history'
        'COSMOS_CONFIG_CONTAINER_NAME' = 'config'
        'SEARCH_INDEX_NAME' = 'azure-chat'
        'OPENAI_DEPLOYMENT_NAME' = 'gpt-4o'
        'OPENAI_API_VERSION' = '2024-08-01-preview'
        'OPENAI_EMBEDDINGS_DEPLOYMENT_NAME' = 'embedding'
        'OPENAI_DALLE_DEPLOYMENT_NAME' = 'dall-e-3'
        'OPENAI_DALLE_API_VERSION' = '2023-12-01-preview'
        'SPEECH_REGION' = 'eastus'
    }
    
    $sharedGroupId = New-VariableGroup -GroupName "azurechat-shared" -Description "Shared variables for Azure Chat application" -Variables $sharedVariables

    # Create development variable group
    Write-Host "📋 Setting up development variable group..."
    $devVariables = @{
        'ENVIRONMENT_NAME' = 'azurechat-dev'
        'WEBAPP_NAME_DEV' = 'azurechat-dev-webapp'
        'KEY_VAULT_NAME_DEV' = 'azurechat-dev-kv'
        'OPENAI_INSTANCE_NAME_DEV' = 'azurechat-dev-openai'
        'OPENAI_DALLE_INSTANCE_NAME_DEV' = 'azurechat-dev-dalle'
        'SEARCH_SERVICE_NAME_DEV' = 'azurechat-dev-search'
        'STORAGE_ACCOUNT_NAME_DEV' = 'azurechatdevstorage'
        'DOCUMENT_INTELLIGENCE_ENDPOINT_DEV' = 'https://azurechat-dev-docint.cognitiveservices.azure.com/'
        'ADMIN_EMAIL_ADDRESS_DEV' = 'dev@yourcompany.com'
        'USE_PRIVATE_ENDPOINTS' = 'false'
    }
    
    $devGroupId = New-VariableGroup -GroupName "azurechat-dev" -Description "Development environment variables for Azure Chat" -Variables $devVariables

    # Create production variable group
    Write-Host "📋 Setting up production variable group..."
    $prodVariables = @{
        'ENVIRONMENT_NAME' = 'azurechat-prod'
        'WEBAPP_NAME_PROD' = 'azurechat-prod-webapp'
        'KEY_VAULT_NAME_PROD' = 'azurechat-prod-kv'
        'OPENAI_INSTANCE_NAME_PROD' = 'azurechat-prod-openai'
        'OPENAI_DALLE_INSTANCE_NAME_PROD' = 'azurechat-prod-dalle'
        'SEARCH_SERVICE_NAME_PROD' = 'azurechat-prod-search'
        'STORAGE_ACCOUNT_NAME_PROD' = 'azurechatprodstorage'
        'DOCUMENT_INTELLIGENCE_ENDPOINT_PROD' = 'https://azurechat-prod-docint.cognitiveservices.azure.com/'
        'ADMIN_EMAIL_ADDRESS_PROD' = 'admin@yourcompany.com'
        'USE_PRIVATE_ENDPOINTS' = 'true'
    }
    
    $prodGroupId = New-VariableGroup -GroupName "azurechat-prod" -Description "Production environment variables for Azure Chat" -Variables $prodVariables

    # Create environments
    Write-Host "🌍 Setting up deployment environments..."
    $devEnvId = New-Environment -EnvName "azurechat-dev" -Description "Development environment for Azure Chat application"
    $prodEnvId = New-Environment -EnvName "azurechat-prod" -Description "Production environment for Azure Chat application"

    # Generate service principal names
    $devSpName = "sp-azurechat-dev-$((Get-Random).ToString().Substring(0,4))"
    $prodSpName = "sp-azurechat-prod-$((Get-Random).ToString().Substring(0,4))"

    Write-Host ""
    Write-Host "🎉 Azure DevOps setup completed successfully!"
    Write-Host ""
    Write-Host "📋 Variable Groups Created:"
    Write-Host "  ✅ azurechat-shared (ID: $sharedGroupId)"
    Write-Host "  ✅ azurechat-dev (ID: $devGroupId)"  
    Write-Host "  ✅ azurechat-prod (ID: $prodGroupId)"
    Write-Host ""
    Write-Host "🌍 Environments Created:"
    Write-Host "  ✅ azurechat-dev (ID: $devEnvId)"
    Write-Host "  ✅ azurechat-prod (ID: $prodEnvId)"
    Write-Host ""
    Write-Host "🔐 Next Steps - Service Connections:"
    Write-Host "1. Create service principals for each environment:"
    Write-Host ""
    Write-Host "   # Development Service Principal"
    Write-Host "   az ad sp create-for-rbac --name `"$devSpName`" --role Contributor --scopes `"/subscriptions/$SubscriptionId/resourceGroups/$DevResourceGroup`""
    Write-Host ""
    Write-Host "   # Production Service Principal"  
    Write-Host "   az ad sp create-for-rbac --name `"$prodSpName`" --role Contributor --scopes `"/subscriptions/$SubscriptionId/resourceGroups/$ProdResourceGroup`""
    Write-Host ""
    Write-Host "2. In Azure DevOps, create service connections:"
    Write-Host "   - Go to Project Settings > Service Connections"
    Write-Host "   - Create 'Azure Resource Manager' connections:"
    Write-Host "     * Name: azure-connection-dev"
    Write-Host "     * Name: azure-connection-prod"
    Write-Host ""
    Write-Host "3. Configure production environment approvals:"
    Write-Host "   - Go to Pipelines > Environments > azurechat-prod"
    Write-Host "   - Add manual approval gate with required reviewers"
    Write-Host ""
    Write-Host "4. Set up Key Vaults and populate secrets (see setup guide)"
    Write-Host ""
    Write-Host "📚 See docs/azure-devops-setup.md for complete configuration details"

}
catch {
    Write-Error "❌ Setup failed: $($_.Exception.Message)"
    Write-Host "💡 Troubleshooting tips:"
    Write-Host "1. Ensure you're logged into Azure CLI: az login"
    Write-Host "2. Verify Azure DevOps permissions in the target organization/project"
    Write-Host "3. Check if the project name and organization are correct"
    exit 1
}