/**
 * Datadog Configuration Utility
 * Centralizes all Datadog-related configuration and environment-specific settings
 */

export interface DatadogEnvironmentConfig {
  service: string;
  env: string;
  version: string;
  site: string;
  tags: Record<string, string>;
  traceEnabled: boolean;
  logLevel: string;
  rumEnabled: boolean;
  profilingEnabled: boolean;
}

// Default configuration values
const DEFAULT_CONFIG: DatadogEnvironmentConfig = {
  service: 'azurechat',
  env: 'development',
  version: '1.0.0',
  site: 'us3.datadoghq.com',
  tags: {},
  traceEnabled: false,
  logLevel: 'info',
  rumEnabled: false,
  profilingEnabled: false
};

/**
 * Get Datadog configuration based on current environment
 */
export function getDatadogConfig(): DatadogEnvironmentConfig {
  const nodeEnv = process.env.NODE_ENV || 'development';

  const config: DatadogEnvironmentConfig = {
    service: process.env.DD_SERVICE || DEFAULT_CONFIG.service,
    env: process.env.DD_ENV || nodeEnv,
    version: process.env.DD_VERSION || DEFAULT_CONFIG.version,
    site: process.env.DD_SITE || DEFAULT_CONFIG.site,
    traceEnabled: process.env.DD_TRACE_ENABLED === 'true',
    logLevel: process.env.DD_LOG_LEVEL || DEFAULT_CONFIG.logLevel,
    rumEnabled: !!(process.env.NEXT_PUBLIC_DD_APPLICATION_ID && process.env.NEXT_PUBLIC_DD_CLIENT_TOKEN),
    profilingEnabled: process.env.DD_PROFILING_ENABLED === 'true',
    tags: {
      ...DEFAULT_CONFIG.tags,
      // Azure-specific tags
      'azure.subscription_id': process.env.AZURE_SUBSCRIPTION_ID || 'unknown',
      'azure.resource_group': process.env.AZURE_RESOURCE_GROUP || 'unknown',
      'azure.region': process.env.AZURE_REGION || process.env.AZURE_LOCATION || 'unknown',

      // Application-specific tags
      'app.name': 'azurechat',
      'app.component': 'web',
      'app.layer': 'application',

      // Environment-specific tags
      'deployment.environment': process.env.DD_ENV || nodeEnv,
      'deployment.version': process.env.DD_VERSION || DEFAULT_CONFIG.version,
      'deployment.region': process.env.AZURE_REGION || 'unknown',

      // Service-specific tags
      'service.name': process.env.DD_SERVICE || DEFAULT_CONFIG.service,
      'service.version': process.env.DD_VERSION || DEFAULT_CONFIG.version,

      // Custom tags from environment
      ...parseCustomTags(process.env.DD_TAGS)
    }
  };

  return config;
}

/**
 * Get RUM-specific configuration for client-side
 */
export function getRumConfig() {
  return {
    applicationId: process.env.NEXT_PUBLIC_DD_APPLICATION_ID,
    clientToken: process.env.NEXT_PUBLIC_DD_CLIENT_TOKEN,
    site: process.env.NEXT_PUBLIC_DD_SITE || 'us3.datadoghq.com',
    service: 'azurechat-frontend',
    env: process.env.NEXT_PUBLIC_DD_ENV || 'development',
    version: process.env.NEXT_PUBLIC_DD_VERSION || '1.0.0'
  };
}

/**
 * Parse custom tags from DD_TAGS environment variable
 * Format: "key1:value1,key2:value2"
 */
function parseCustomTags(ddTags?: string): Record<string, string> {
  if (!ddTags) return {};

  const tags: Record<string, string> = {};

  try {
    ddTags.split(',').forEach(tag => {
      const [key, value] = tag.split(':');
      if (key && value) {
        tags[key.trim()] = value.trim();
      }
    });
  } catch (error) {
    console.warn('Failed to parse DD_TAGS:', error);
  }

  return tags;
}

/**
 * Environment-specific configuration presets
 */
export const ENVIRONMENT_PRESETS = {
  development: {
    traceEnabled: false,
    logLevel: 'debug',
    profilingEnabled: false,
    tags: {
      'environment.type': 'development',
      'cost.center': 'engineering',
      'team': 'ai-platform'
    }
  },

  staging: {
    traceEnabled: true,
    logLevel: 'info',
    profilingEnabled: false,
    tags: {
      'environment.type': 'staging',
      'cost.center': 'engineering',
      'team': 'ai-platform'
    }
  },

  production: {
    traceEnabled: true,
    logLevel: 'warn',
    profilingEnabled: true,
    tags: {
      'environment.type': 'production',
      'cost.center': 'production',
      'team': 'ai-platform',
      'sla.tier': 'tier-1'
    }
  }
};

/**
 * Apply environment-specific preset configurations
 */
export function applyEnvironmentPreset(config: DatadogEnvironmentConfig): DatadogEnvironmentConfig {
  const preset = ENVIRONMENT_PRESETS[config.env as keyof typeof ENVIRONMENT_PRESETS];

  if (preset) {
    return {
      ...config,
      ...preset,
      tags: {
        ...config.tags,
        ...preset.tags
      }
    };
  }

  return config;
}

/**
 * Generate tags for specific Azure services
 */
export const AzureServiceTags = {
  openai: (instanceName?: string, deploymentName?: string) => ({
    'azure.service': 'openai',
    'azure.openai.instance': instanceName || 'unknown',
    'azure.openai.deployment': deploymentName || 'unknown',
    'service.type': 'ai-service'
  }),

  cosmos: (accountName?: string, databaseName?: string) => ({
    'azure.service': 'cosmos-db',
    'azure.cosmos.account': accountName || 'unknown',
    'azure.cosmos.database': databaseName || 'unknown',
    'service.type': 'database'
  }),

  search: (serviceName?: string, indexName?: string) => ({
    'azure.service': 'ai-search',
    'azure.search.service': serviceName || 'unknown',
    'azure.search.index': indexName || 'unknown',
    'service.type': 'search-service'
  }),

  storage: (accountName?: string, containerName?: string) => ({
    'azure.service': 'storage-blob',
    'azure.storage.account': accountName || 'unknown',
    'azure.storage.container': containerName || 'unknown',
    'service.type': 'storage'
  }),

  keyvault: (vaultName?: string) => ({
    'azure.service': 'key-vault',
    'azure.keyvault.name': vaultName || 'unknown',
    'service.type': 'secrets-management'
  })
};

/**
 * Validate Datadog configuration
 */
export function validateDatadogConfig(config: DatadogEnvironmentConfig): string[] {
  const errors: string[] = [];

  if (config.traceEnabled && !process.env.DD_API_KEY) {
    errors.push('DD_API_KEY is required when DD_TRACE_ENABLED is true');
  }

  if (config.rumEnabled && (!process.env.NEXT_PUBLIC_DD_APPLICATION_ID || !process.env.NEXT_PUBLIC_DD_CLIENT_TOKEN)) {
    errors.push('NEXT_PUBLIC_DD_APPLICATION_ID and NEXT_PUBLIC_DD_CLIENT_TOKEN are required for RUM');
  }

  if (!config.service || config.service.trim() === '') {
    errors.push('Service name cannot be empty');
  }

  if (!config.env || config.env.trim() === '') {
    errors.push('Environment cannot be empty');
  }

  return errors;
}