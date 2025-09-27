import tracer from 'dd-trace';
import { getDatadogConfig, applyEnvironmentPreset, validateDatadogConfig } from './datadog-config';

// Initialize Datadog APM tracing
export function initializeDatadog() {
  const config = applyEnvironmentPreset(getDatadogConfig());

  // Validate configuration
  const validationErrors = validateDatadogConfig(config);
  if (validationErrors.length > 0) {
    console.warn('[Datadog] Configuration validation warnings:', validationErrors);
  }

  // Only initialize if tracing is enabled
  if (config.traceEnabled) {
    tracer.init({
      service: config.service,
      env: config.env,
      version: config.version,
      logInjection: true,
      runtimeMetrics: true,
      profiling: config.profilingEnabled,
      plugins: {
        // Next.js plugin configuration
        next: {
          enabled: true
        },
        // HTTP plugin for API calls
        http: {
          enabled: true,
          service: `${config.service}-http`
        },
        // Fetch plugin for modern HTTP requests
        fetch: {
          enabled: true,
          service: `${config.service}-fetch`
        },
        // Azure SDK plugins
        'azure-cosmos': {
          enabled: true,
          service: `${config.service}-cosmos`
        },
        'azure-storage-blob': {
          enabled: true,
          service: `${config.service}-storage`
        }
      },
      tags: config.tags
    });

    console.log(`[Datadog] APM tracing initialized for service: ${config.service} (env: ${config.env})`);
    console.log(`[Datadog] Configuration:`, {
      service: config.service,
      env: config.env,
      version: config.version,
      site: config.site,
      profilingEnabled: config.profilingEnabled
    });
  } else {
    console.log('[Datadog] Tracing disabled - set DD_TRACE_ENABLED=true to enable');
  }

  return tracer;
}

// Export the tracer instance
export { tracer };

// Custom span creation helper
export function createSpan(operationName: string, options?: any) {
  return tracer.trace(operationName, options);
}

// Add custom tags to current span
export function addTags(tags: Record<string, any>) {
  const span = tracer.scope().active();
  if (span) {
    span.addTags(tags);
  }
}

// Log with trace correlation
export function logWithTrace(level: 'info' | 'warn' | 'error', message: string, metadata?: any) {
  const span = tracer.scope().active();
  const traceId = span ? span.context().toTraceId() : 'no-trace';
  const spanId = span ? span.context().toSpanId() : 'no-span';

  const logEntry = {
    timestamp: new Date().toISOString(),
    level,
    message,
    dd: {
      trace_id: traceId,
      span_id: spanId
    },
    service: 'azurechat',
    ...metadata
  };

  console.log(JSON.stringify(logEntry));
}