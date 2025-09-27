# Datadog Monitoring Integration

## Overview

This document provides comprehensive guidance on integrating Datadog monitoring into your Azure Chat application. The integration includes:

- **APM (Application Performance Monitoring)** for distributed tracing
- **RUM (Real User Monitoring)** for frontend monitoring
- **Structured JSON logging** with trace correlation
- **Custom metrics and dashboards** for Azure OpenAI interactions
- **Error tracking and alerting**

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Configuration](#environment-configuration)
3. [APM Configuration](#apm-configuration)
4. [RUM Configuration](#rum-configuration)
5. [Logging Configuration](#logging-configuration)
6. [Azure Service Integration](#azure-service-integration)
7. [Dashboard Setup](#dashboard-setup)
8. [Alerting](#alerting)
9. [Troubleshooting](#troubleshooting)
10. [Best Practices](#best-practices)

## Prerequisites

1. **Datadog Account**: You need a Datadog account with access to us3.datadog.com
2. **API Keys**:
   - Datadog API Key for APM and logging
   - RUM Application ID and Client Token for frontend monitoring
3. **Next.js 14**: This integration is designed for Next.js 14 with App Router

## Environment Configuration

### Required Environment Variables

Add these variables to your `.env.local` file:

```bash
# Datadog APM and Logging Configuration
DD_API_KEY=your-datadog-api-key
DD_SITE=us3.datadoghq.com
DD_SERVICE=azurechat
DD_ENV=production  # or development, staging
DD_VERSION=1.0.0
DD_TRACE_ENABLED=true

# RUM (Real User Monitoring) Configuration
NEXT_PUBLIC_DD_APPLICATION_ID=your-rum-application-id
NEXT_PUBLIC_DD_CLIENT_TOKEN=your-rum-client-token
NEXT_PUBLIC_DD_SITE=us3.datadoghq.com
NEXT_PUBLIC_DD_ENV=production
NEXT_PUBLIC_DD_VERSION=1.0.0

# Optional Datadog settings
DD_LOGS_INJECTION=true
DD_RUNTIME_METRICS_ENABLED=true
DD_PROFILING_ENABLED=false  # Enable in production for detailed profiling
DD_TAGS=team:ai-platform,cost-center:production
```

### Environment-Specific Configuration

The integration automatically applies different configurations based on the environment:

#### Development
- **Tracing**: Disabled by default
- **Log Level**: Debug
- **RUM Sampling**: 100%
- **Session Replay**: Disabled

#### Staging
- **Tracing**: Enabled
- **Log Level**: Info
- **RUM Sampling**: 100%
- **Session Replay**: 20%

#### Production
- **Tracing**: Enabled
- **Log Level**: Warn
- **RUM Sampling**: 50% (cost optimization)
- **Session Replay**: 10%
- **Profiling**: Enabled

## APM Configuration

### Automatic Instrumentation

The application automatically instruments:

- **Next.js requests** and responses
- **HTTP/HTTPS requests** to external services
- **Azure SDK calls** (Cosmos DB, Storage, Search, OpenAI)
- **Database operations**

### Custom Spans

Create custom spans for specific operations:

```typescript
import { createSpan } from '@/lib/datadog';

// Wrap any async operation
const result = await createSpan('custom.operation', {
  resource: 'business-logic',
  service: 'azurechat'
}, async () => {
  // Your business logic here
  return await performOperation();
});
```

### Tags and Metadata

Spans are automatically tagged with:
- Service name and version
- Environment information
- Azure subscription and region
- User context (when available)
- Chat session information

## RUM Configuration

### Frontend Monitoring

RUM automatically tracks:
- **Page loads** and navigation
- **User interactions** (clicks, form submissions)
- **AJAX requests** to APIs
- **JavaScript errors**
- **Core Web Vitals**

### Custom Events

Track specific user actions:

```typescript
import { useDatadogRum } from '@/lib/datadog-rum';

function ChatComponent() {
  const rum = useDatadogRum();

  const handleSendMessage = async (message: string) => {
    // Track chat interaction
    rum.trackChatEvent('message_sent', {
      messageLength: message.length,
      hasAttachments: false,
      chatId: currentChatId
    });

    // Send message logic
    await sendMessage(message);
  };
}
```

### User Context

Set user context for better tracking:

```typescript
// Set user information (do not include PII)
rum.setUser(userId, {
  role: 'user',
  subscription: 'premium'
});
```

## Logging Configuration

### Structured JSON Logging

All logs are structured as JSON with trace correlation:

```json
{
  "timestamp": "2024-03-01T12:00:00.000Z",
  "level": "info",
  "message": "Chat request processed",
  "service": "azurechat",
  "environment": "production",
  "version": "1.0.0",
  "category": "chat_processing",
  "chatId": "chat_123",
  "userId": "user_456",
  "duration": 1250,
  "dd": {
    "trace_id": "1234567890123456",
    "span_id": "1234567890123456"
  }
}
```

### Log Categories

The application uses specific log categories:

- `api_request` - HTTP API requests
- `api_response` - HTTP API responses
- `api_error` - API errors
- `chat_processing` - Chat message processing
- `azure_openai` - Azure OpenAI interactions
- `azure_service` - Other Azure service calls
- `user_action` - User interactions
- `file_operation` - File uploads/downloads
- `authentication` - Auth events
- `performance` - Performance metrics

### Custom Logging

Use the logger throughout your application:

```typescript
import { logger, createLogger } from '@/lib/logger';

// Basic logging
logger.info('Operation completed', { userId: '123', duration: 500 });
logger.error('Operation failed', error, { context: 'additional info' });

// Specialized logging
logger.chatEvent('message_processed', { chatId: '123' });
logger.azureOpenAI('completion_requested', { model: 'gpt-4', tokens: 150 });
logger.userAction('file_uploaded', userId, { fileName: 'document.pdf', size: 1024000 });

// Create contextual logger
const requestLogger = createLogger({ requestId: '123', userId: '456' });
requestLogger.info('Processing request');  // Automatically includes context
```

## Azure Service Integration

### Azure OpenAI Monitoring

The integration provides detailed monitoring of Azure OpenAI interactions:

- **Request/response times**
- **Token usage tracking**
- **Model performance metrics**
- **Error rates and types**
- **Cost analysis data**

### Azure Cosmos DB

Monitors database operations:

- **Query performance**
- **Request units (RU) consumption**
- **Connection pool metrics**
- **Error tracking**

### Azure AI Search

Tracks search operations:

- **Search query performance**
- **Index utilization**
- **Relevance scoring**
- **Error rates**

### Azure Storage

Monitors file operations:

- **Upload/download performance**
- **Storage utilization**
- **Bandwidth metrics**
- **Access patterns**

## Dashboard Setup

### Recommended Dashboards

Create the following dashboards in Datadog:

#### 1. Application Overview
- Request volume and response times
- Error rates by endpoint
- User session metrics
- Azure service health

#### 2. Azure OpenAI Performance
- Completion request volume
- Token usage trends
- Model performance comparison
- Cost tracking

#### 3. Chat Analytics
- Active chat sessions
- Message volume trends
- User engagement metrics
- Feature usage (personas, extensions, file uploads)

#### 4. Infrastructure Health
- Server performance metrics
- Database performance
- Storage utilization
- Network latency

### Dashboard Queries

Example queries for custom dashboards:

```javascript
// Average response time by endpoint
avg:trace.web.request.duration{service:azurechat} by {resource_name}

// Error rate by service
sum:trace.web.request.errors{service:azurechat}.as_rate()

// Azure OpenAI token usage
sum:azurechat.openai.tokens{} by {model,deployment}

// Chat message volume
sum:azurechat.chat.messages{} by {chat_type}
```

## Alerting

### Recommended Alerts

Set up alerts for critical metrics:

#### High Priority Alerts

1. **High Error Rate**
   - Condition: Error rate > 5% for 5 minutes
   - Notification: PagerDuty + Slack

2. **Azure OpenAI Failures**
   - Condition: OpenAI error rate > 1% for 3 minutes
   - Notification: Email + Slack

3. **High Response Time**
   - Condition: p95 response time > 5 seconds for 5 minutes
   - Notification: Slack

#### Medium Priority Alerts

1. **Database Performance**
   - Condition: Cosmos DB RU consumption > 80%
   - Notification: Email

2. **Storage Utilization**
   - Condition: Storage utilization > 85%
   - Notification: Email

3. **Unusual Traffic Patterns**
   - Condition: Request volume anomaly detection
   - Notification: Slack

### Alert Configuration Example

```yaml
# High error rate alert
name: "Azure Chat - High Error Rate"
type: "metric alert"
query: "avg(last_5m):sum:trace.web.request.errors{service:azurechat}.as_rate() > 0.05"
message: |
  Azure Chat is experiencing a high error rate.

  Current error rate: {{value}}%

  Check the APM dashboard: https://app.datadoghq.com/apm/service/azurechat
tags:
  - "service:azurechat"
  - "priority:high"
```

## Troubleshooting

### Common Issues

#### 1. Tracing Not Working

**Symptoms**: No traces appearing in Datadog

**Solutions**:
- Verify `DD_TRACE_ENABLED=true`
- Check `DD_API_KEY` is set correctly
- Ensure `instrumentation.ts` is being loaded
- Check browser console for client-side issues

#### 2. Missing Logs

**Symptoms**: Logs not appearing in Datadog

**Solutions**:
- Verify log format is JSON
- Check `DD_LOGS_INJECTION=true`
- Ensure proper Datadog agent configuration
- Check log level settings

#### 3. RUM Not Initializing

**Symptoms**: No RUM data in Datadog

**Solutions**:
- Verify `NEXT_PUBLIC_DD_APPLICATION_ID` and `NEXT_PUBLIC_DD_CLIENT_TOKEN`
- Check browser console for initialization errors
- Ensure RUM script is loading correctly
- Verify domain is allowed in RUM settings

#### 4. High Data Usage

**Symptoms**: Unexpectedly high Datadog costs

**Solutions**:
- Adjust sampling rates in production
- Review log retention settings
- Optimize tag cardinality
- Use environment-specific configurations

### Debug Mode

Enable debug logging to troubleshoot issues:

```bash
# Enable debug logging
DEBUG=dd-trace:*
DD_TRACE_DEBUG=true
DD_LOG_LEVEL=debug
```

## Best Practices

### Performance

1. **Sampling**: Use appropriate sampling rates for each environment
2. **Tag Cardinality**: Avoid high-cardinality tags (unique IDs, timestamps)
3. **Log Volume**: Balance observability with cost by setting appropriate log levels
4. **Async Logging**: Ensure logging doesn't block application performance

### Security

1. **PII Protection**: Never log personally identifiable information
2. **Secret Management**: Store Datadog credentials securely
3. **Network Security**: Configure proper firewall rules for Datadog agents
4. **Access Control**: Use principle of least privilege for Datadog access

### Data Governance

1. **Retention Policies**: Set appropriate data retention based on compliance needs
2. **Data Classification**: Tag sensitive operations appropriately
3. **Audit Logging**: Maintain audit trails for compliance
4. **Data Location**: Ensure data residency requirements are met

### Cost Optimization

1. **Environment-Specific Configs**: Use different settings per environment
2. **Smart Sampling**: Higher sampling in non-production environments
3. **Log Optimization**: Use structured logging with appropriate levels
4. **Dashboard Efficiency**: Create efficient queries to reduce compute costs

### Monitoring Strategy

1. **SLI/SLO Definition**: Define clear service level indicators and objectives
2. **Alert Fatigue**: Avoid too many alerts; focus on actionable items
3. **Dashboard Hierarchy**: Create overview and drill-down dashboards
4. **Regular Reviews**: Periodically review and update monitoring configuration

## Next Steps

1. **Set up your Datadog account** and obtain API keys
2. **Configure environment variables** in your deployment
3. **Deploy the application** with monitoring enabled
4. **Create dashboards** using the recommended templates
5. **Configure alerts** for critical metrics
6. **Train your team** on using Datadog for troubleshooting

For additional support or questions about Datadog integration, please refer to the [Datadog documentation](https://docs.datadoghq.com/) or contact your Datadog support team.

---

[← Previous: Managed Identity-based deployment](./9-managed-identities.md) | [Next: Migration considerations →](./migration.md)