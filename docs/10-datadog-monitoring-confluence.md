# Azure Chat - Datadog Monitoring Integration Guide

<ac:structured-macro ac:name="info">
<ac:rich-text-body>
<p>This page provides comprehensive guidance on integrating Datadog monitoring into your Azure Chat application for production-ready observability.</p>
</ac:rich-text-body>
</ac:structured-macro>

## Overview

The Datadog integration provides comprehensive monitoring capabilities for the Azure Chat application, including:

<ac:structured-macro ac:name="expand">
<ac:parameter ac:name="title">Monitoring Features</ac:parameter>
<ac:rich-text-body>
<ul>
<li><strong>APM (Application Performance Monitoring)</strong>: Distributed tracing across all application components</li>
<li><strong>RUM (Real User Monitoring)</strong>: Frontend performance and user experience monitoring</li>
<li><strong>Structured JSON Logging</strong>: Centralized logging with trace correlation</li>
<li><strong>Azure Service Integration</strong>: Specialized monitoring for OpenAI, Cosmos DB, and other Azure services</li>
<li><strong>Custom Dashboards</strong>: Pre-configured dashboards for different stakeholder needs</li>
<li><strong>Intelligent Alerting</strong>: Context-aware alerts with proper escalation paths</li>
</ul>
</ac:rich-text-body>
</ac:structured-macro>

---

## Prerequisites

<ac:structured-macro ac:name="warning">
<ac:rich-text-body>
<p>Ensure you have the following before starting the integration:</p>
</ac:rich-text-body>
</ac:structured-macro>

### Required Accounts and Access

<table>
<tr>
<th>Requirement</th>
<th>Description</th>
<th>Access Level</th>
</tr>
<tr>
<td>Datadog Account</td>
<td>Active Datadog account with us3.datadog.com</td>
<td>Admin or Editor</td>
</tr>
<tr>
<td>API Keys</td>
<td>Datadog API Key for APM and logging</td>
<td>API Keys management</td>
</tr>
<tr>
<td>RUM Application</td>
<td>RUM Application ID and Client Token</td>
<td>RUM configuration</td>
</tr>
<tr>
<td>Azure Subscription</td>
<td>Azure subscription with deployed Azure Chat</td>
<td>Contributor</td>
</tr>
</table>

---

## Environment Configuration

### Step 1: Configure Environment Variables

<ac:structured-macro ac:name="code">
<ac:parameter ac:name="language">bash</ac:parameter>
<ac:parameter ac:name="title">.env.local Configuration</ac:parameter>
<ac:rich-text-body>
<![CDATA[
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
DD_PROFILING_ENABLED=false  # Enable in production
DD_TAGS=team:ai-platform,cost-center:production
]]>
</ac:rich-text-body>
</ac:structured-macro>

### Step 2: Environment-Specific Settings

<ac:structured-macro ac:name="expand">
<ac:parameter ac:name="title">Development Environment</ac:parameter>
<ac:rich-text-body>
<ul>
<li><strong>Tracing</strong>: Disabled by default (DD_TRACE_ENABLED=false)</li>
<li><strong>Log Level</strong>: Debug</li>
<li><strong>RUM Sampling</strong>: 100%</li>
<li><strong>Session Replay</strong>: Disabled (0%)</li>
<li><strong>Profiling</strong>: Disabled</li>
</ul>
</ac:rich-text-body>
</ac:structured-macro>

<ac:structured-macro ac:name="expand">
<ac:parameter ac:name="title">Staging Environment</ac:parameter>
<ac:rich-text-body>
<ul>
<li><strong>Tracing</strong>: Enabled (DD_TRACE_ENABLED=true)</li>
<li><strong>Log Level</strong>: Info</li>
<li><strong>RUM Sampling</strong>: 100%</li>
<li><strong>Session Replay</strong>: 20%</li>
<li><strong>Profiling</strong>: Disabled</li>
</ul>
</ac:rich-text-body>
</ac:structured-macro>

<ac:structured-macro ac:name="expand">
<ac:parameter ac:name="title">Production Environment</ac:parameter>
<ac:rich-text-body>
<ul>
<li><strong>Tracing</strong>: Enabled (DD_TRACE_ENABLED=true)</li>
<li><strong>Log Level</strong>: Warn</li>
<li><strong>RUM Sampling</strong>: 50% (cost optimization)</li>
<li><strong>Session Replay</strong>: 10%</li>
<li><strong>Profiling</strong>: Enabled (DD_PROFILING_ENABLED=true)</li>
</ul>
</ac:rich-text-body>
</ac:structured-macro>

---

## APM (Application Performance Monitoring)

### Automatic Instrumentation

The integration automatically instruments the following components:

<table>
<tr>
<th>Component</th>
<th>What's Monitored</th>
<th>Metrics Available</th>
</tr>
<tr>
<td>Next.js Requests</td>
<td>All HTTP requests and responses</td>
<td>Response time, error rate, throughput</td>
</tr>
<tr>
<td>Azure OpenAI</td>
<td>Completion requests, token usage</td>
<td>Latency, success rate, token consumption</td>
</tr>
<tr>
<td>Cosmos DB</td>
<td>Database queries, RU consumption</td>
<td>Query performance, connection health</td>
</tr>
<tr>
<td>Azure Search</td>
<td>Search queries, index operations</td>
<td>Query latency, relevance scoring</td>
</tr>
<tr>
<td>Blob Storage</td>
<td>File operations, data transfers</td>
<td>Transfer speed, storage utilization</td>
</tr>
</table>

### Custom Spans Example

<ac:structured-macro ac:name="code">
<ac:parameter ac:name="language">typescript</ac:parameter>
<ac:parameter ac:name="title">Creating Custom Spans</ac:parameter>
<ac:rich-text-body>
<![CDATA[
import { createSpan } from '@/lib/datadog';

// Wrap business logic operations
const processUserRequest = async (userId: string, request: any) => {
  return await createSpan('user.request.process', {
    resource: 'business-logic',
    service: 'azurechat',
    tags: {
      'user.id': userId,
      'request.type': request.type
    }
  }, async () => {
    // Your business logic here
    return await performComplexOperation(userId, request);
  });
};
]]>
</ac:rich-text-body>
</ac:structured-macro>

---

## RUM (Real User Monitoring)

### Frontend Tracking Capabilities

<ac:structured-macro ac:name="note">
<ac:rich-text-body>
<p>RUM provides insights into actual user experience and frontend performance.</p>
</ac:rich-text-body>
</ac:structured-macro>

#### Automatic Tracking
- **Page Navigation**: Route changes and page load times
- **User Interactions**: Clicks, form submissions, scrolling
- **AJAX Requests**: API calls with response times
- **JavaScript Errors**: Runtime errors with stack traces
- **Core Web Vitals**: LCP, FID, CLS measurements

#### Custom Event Tracking

<ac:structured-macro ac:name="code">
<ac:parameter ac:name="language">typescript</ac:parameter>
<ac:parameter ac:name="title">Custom RUM Event Tracking</ac:parameter>
<ac:rich-text-body>
<![CDATA[
import { useDatadogRum } from '@/lib/datadog-rum';

function ChatInterface() {
  const rum = useDatadogRum();

  const handleChatAction = async (action: string, metadata: any) => {
    // Track specific chat events
    rum.trackChatEvent('message_sent', {
      messageLength: metadata.length,
      hasAttachments: metadata.attachments?.length > 0,
      chatId: metadata.chatId,
      personaUsed: metadata.personaId !== null
    });
  };

  const handleFileUpload = async (file: File) => {
    rum.trackFileUpload(file.name, file.size, file.type, true);
  };

  // Set user context (no PII)
  React.useEffect(() => {
    rum.setUser(userId, {
      role: userRole,
      subscription: subscriptionTier
    });
  }, [userId]);
}
]]>
</ac:rich-text-body>
</ac:structured-macro>

---

## Structured Logging

### Log Format and Structure

<ac:structured-macro ac:name="info">
<ac:rich-text-body>
<p>All logs are structured as JSON with automatic trace correlation to connect logs with APM traces.</p>
</ac:rich-text-body>
</ac:structured-macro>

<ac:structured-macro ac:name="code">
<ac:parameter ac:name="language">json</ac:parameter>
<ac:parameter ac:name="title">Example Log Entry</ac:parameter>
<ac:rich-text-body>
<![CDATA[
{
  "timestamp": "2024-03-01T12:00:00.000Z",
  "level": "info",
  "message": "Azure OpenAI completion requested",
  "service": "azurechat",
  "environment": "production",
  "version": "1.0.0",
  "category": "azure_openai",
  "action": "completion_request",
  "chatId": "chat_abc123",
  "userId": "user_def456",
  "model": "gpt-4",
  "tokens": 150,
  "duration": 1250,
  "dd": {
    "trace_id": "1234567890123456",
    "span_id": "6789012345678901"
  }
}
]]>
</ac:rich-text-body>
</ac:structured-macro>

### Log Categories

<table>
<tr>
<th>Category</th>
<th>Purpose</th>
<th>Example Use Cases</th>
</tr>
<tr>
<td>api_request</td>
<td>HTTP API requests</td>
<td>Request volume, endpoint usage</td>
</tr>
<tr>
<td>azure_openai</td>
<td>OpenAI interactions</td>
<td>Token usage, model performance</td>
</tr>
<tr>
<td>chat_processing</td>
<td>Chat operations</td>
<td>Message processing, conversation flow</td>
</tr>
<tr>
<td>user_action</td>
<td>User interactions</td>
<td>Feature usage, user behavior</td>
</tr>
<tr>
<td>performance</td>
<td>Performance metrics</td>
<td>Operation timing, bottlenecks</td>
</tr>
<tr>
<td>azure_service</td>
<td>Azure service calls</td>
<td>Service health, operation success</td>
</tr>
</table>

### Custom Logging Examples

<ac:structured-macro ac:name="code">
<ac:parameter ac:name="language">typescript</ac:parameter>
<ac:parameter ac:name="title">Using the Logger</ac:parameter>
<ac:rich-text-body>
<![CDATA[
import { logger, createLogger } from '@/lib/logger';

// Basic logging with context
logger.info('User uploaded file', {
  userId: 'user123',
  fileName: 'document.pdf',
  fileSize: 1048576,
  category: 'file_operation'
});

// Specialized logging methods
logger.azureOpenAI('completion_completed', {
  model: 'gpt-4',
  tokens_used: 250,
  response_time: 1500
});

logger.chatEvent('conversation_started', {
  chatId: 'chat_456',
  personaId: 'persona_789',
  hasDocuments: true
});

// Create contextual logger for request processing
const requestLogger = createLogger({
  requestId: req.headers['x-request-id'],
  userId: session.userId
});

requestLogger.info('Processing chat request');
requestLogger.performance('request_completed', 2500);
]]>
</ac:rich-text-body>
</ac:structured-macro>

---

## Dashboard Configuration

### Recommended Dashboards

<ac:structured-macro ac:name="expand">
<ac:parameter ac:name="title">1. Executive Overview Dashboard</ac:parameter>
<ac:rich-text-body>
<p><strong>Target Audience:</strong> Engineering managers, Product owners</p>
<p><strong>Key Metrics:</strong></p>
<ul>
<li>Application uptime and availability</li>
<li>User engagement metrics</li>
<li>Error rates and trends</li>
<li>Azure OpenAI cost and usage</li>
<li>Performance SLA compliance</li>
</ul>
</ac:rich-text-body>
</ac:structured-macro>

<ac:structured-macro ac:name="expand">
<ac:parameter ac:name="title">2. Engineering Operations Dashboard</ac:parameter>
<ac:rich-text-body>
<p><strong>Target Audience:</strong> DevOps engineers, Site reliability engineers</p>
<p><strong>Key Metrics:</strong></p>
<ul>
<li>Request volume and latency by endpoint</li>
<li>Error rates and error types</li>
<li>Database performance and RU consumption</li>
<li>Infrastructure health metrics</li>
<li>Deployment success rates</li>
</ul>
</ac:rich-text-body>
</ac:structured-macro>

<ac:structured-macro ac:name="expand">
<ac:parameter ac:name="title">3. Azure OpenAI Analytics Dashboard</ac:parameter>
<ac:rich-text-body>
<p><strong>Target Audience:</strong> AI/ML engineers, Product analysts</p>
<p><strong>Key Metrics:</strong></p>
<ul>
<li>Token usage trends by model</li>
<li>Completion quality metrics</li>
<li>Cost analysis and optimization</li>
<li>Model performance comparison</li>
<li>Feature usage analytics (personas, extensions)</li>
</ul>
</ac:rich-text-body>
</ac:structured-macro>

<ac:structured-macro ac:name="expand">
<ac:parameter ac:name="title">4. User Experience Dashboard</ac:parameter>
<ac:rich-text-body>
<p><strong>Target Audience:</strong> UX designers, Product managers</p>
<p><strong>Key Metrics:</strong></p>
<ul>
<li>Core Web Vitals and page load times</li>
<li>User interaction patterns</li>
<li>Session duration and engagement</li>
<li>Error impact on user experience</li>
<li>Feature adoption rates</li>
</ul>
</ac:rich-text-body>
</ac:structured-macro>

---

## Alerting Strategy

### Alert Priorities and Escalation

<ac:structured-macro ac:name="warning">
<ac:parameter ac:name="title">Critical Alerts (P1)</ac:parameter>
<ac:rich-text-body>
<p><strong>Response Time:</strong> 15 minutes<br/>
<strong>Escalation:</strong> PagerDuty → Slack → Phone call</p>
</ac:rich-text-body>
</ac:structured-macro>

<table>
<tr>
<th>Alert</th>
<th>Condition</th>
<th>Impact</th>
</tr>
<tr>
<td>Application Down</td>
<td>Error rate > 50% for 2 minutes</td>
<td>Complete service outage</td>
</tr>
<tr>
<td>Azure OpenAI Failure</td>
<td>OpenAI error rate > 10% for 3 minutes</td>
<td>Core functionality unavailable</td>
</tr>
<tr>
<td>Database Unavailable</td>
<td>Cosmos DB connection failures > 5%</td>
<td>Data access issues</td>
</tr>
</table>

<ac:structured-macro ac:name="note">
<ac:parameter ac:name="title">High Priority Alerts (P2)</ac:parameter>
<ac:rich-text-body>
<p><strong>Response Time:</strong> 1 hour<br/>
<strong>Escalation:</strong> Slack → Email</p>
</ac:rich-text-body>
</ac:structured-macro>

<table>
<tr>
<th>Alert</th>
<th>Condition</th>
<th>Impact</th>
</tr>
<tr>
<td>High Response Time</td>
<td>p95 response time > 5 seconds</td>
<td>Degraded user experience</td>
</tr>
<tr>
<td>Elevated Error Rate</td>
<td>Error rate > 5% for 10 minutes</td>
<td>Partial service degradation</td>
</tr>
<tr>
<td>High Resource Usage</td>
<td>CPU/Memory > 80% for 15 minutes</td>
<td>Performance issues</td>
</tr>
</table>

### Alert Configuration Examples

<ac:structured-macro ac:name="code">
<ac:parameter ac:name="language">yaml</ac:parameter>
<ac:parameter ac:name="title">Sample Alert Configuration</ac:parameter>
<ac:rich-text-body>
<![CDATA[
# Critical: High Error Rate Alert
name: "Azure Chat - Critical Error Rate"
type: "metric alert"
query: "avg(last_5m):sum:trace.web.request.errors{service:azurechat}.as_rate() > 0.1"
message: |
  🚨 CRITICAL: Azure Chat is experiencing high error rates

  Current error rate: {{value}}%
  Threshold: 10%

  Immediate action required:
  1. Check APM traces: https://app.datadoghq.com/apm/service/azurechat
  2. Review recent deployments
  3. Check Azure service health

  Escalation: @pagerduty-azurechat @slack-engineering

thresholds:
  critical: 0.1
  warning: 0.05

tags:
  - "service:azurechat"
  - "priority:critical"
  - "team:ai-platform"
]]>
</ac:rich-text-body>
</ac:structured-macro>

---

## Troubleshooting Guide

### Common Issues and Solutions

<ac:structured-macro ac:name="expand">
<ac:parameter ac:name="title">Issue: No APM Traces Visible</ac:parameter>
<ac:rich-text-body>
<p><strong>Symptoms:</strong></p>
<ul>
<li>No traces in APM dashboard</li>
<li>Service not appearing in service list</li>
</ul>
<p><strong>Solutions:</strong></p>
<ol>
<li>Verify <code>DD_TRACE_ENABLED=true</code> in environment variables</li>
<li>Check <code>DD_API_KEY</code> is correctly set and valid</li>
<li>Ensure <code>instrumentation.ts</code> is being loaded by Next.js</li>
<li>Check application logs for Datadog initialization messages</li>
<li>Verify network connectivity to Datadog (us3.datadoghq.com)</li>
</ol>
</ac:rich-text-body>
</ac:structured-macro>

<ac:structured-macro ac:name="expand">
<ac:parameter ac:name="title">Issue: RUM Data Not Appearing</ac:parameter>
<ac:rich-text-body>
<p><strong>Symptoms:</strong></p>
<ul>
<li>No user sessions in RUM dashboard</li>
<li>Missing frontend performance data</li>
</ul>
<p><strong>Solutions:</strong></p>
<ol>
<li>Verify <code>NEXT_PUBLIC_DD_APPLICATION_ID</code> and <code>NEXT_PUBLIC_DD_CLIENT_TOKEN</code></li>
<li>Check browser console for RUM initialization errors</li>
<li>Ensure domain is whitelisted in Datadog RUM settings</li>
<li>Verify NEXT_PUBLIC_* variables are available in browser</li>
<li>Check Content Security Policy (CSP) settings</li>
</ol>
</ac:rich-text-body>
</ac:structured-macro>

<ac:structured-macro ac:name="expand">
<ac:parameter ac:name="title">Issue: High Datadog Costs</ac:parameter>
<ac:rich-text-body>
<p><strong>Symptoms:</strong></p>
<ul>
<li>Unexpected billing increases</li>
<li>High log volume or trace volume</li>
</ul>
<p><strong>Solutions:</strong></p>
<ol>
<li>Review and adjust sampling rates for production</li>
<li>Optimize log levels (use WARN in production)</li>
<li>Remove high-cardinality tags</li>
<li>Set up log exclusion filters</li>
<li>Review data retention settings</li>
<li>Monitor usage with Datadog usage dashboards</li>
</ol>
</ac:rich-text-body>
</ac:structured-macro>

### Debug Mode

<ac:structured-macro ac:name="code">
<ac:parameter ac:name="language">bash</ac:parameter>
<ac:parameter ac:name="title">Enable Debug Logging</ac:parameter>
<ac:rich-text-body>
<![CDATA[
# Enable comprehensive debug logging
DEBUG=dd-trace:*
DD_TRACE_DEBUG=true
DD_LOG_LEVEL=debug

# Start application with debug output
npm run dev 2>&1 | tee datadog-debug.log
]]>
</ac:rich-text-body>
</ac:structured-macro>

---

## Best Practices

### Performance Optimization

<ac:structured-macro ac:name="tip">
<ac:rich-text-body>
<p>Follow these practices to maintain optimal performance while maximizing observability value.</p>
</ac:rich-text-body>
</ac:structured-macro>

#### Sampling Strategy
- **Development**: 100% sampling for debugging
- **Staging**: 100% sampling for testing
- **Production**: 50% sampling to balance cost and visibility

#### Tag Management
- Use consistent tag naming conventions
- Avoid high-cardinality tags (unique IDs, timestamps)
- Focus on business-relevant dimensions

#### Log Optimization
- Use structured logging consistently
- Set appropriate log levels per environment
- Implement async logging to prevent blocking

### Security Considerations

<ac:structured-macro ac:name="warning">
<ac:rich-text-body>
<p>Never log personally identifiable information (PII) or sensitive data.</p>
</ac:rich-text-body>
</ac:structured-macro>

#### Data Protection
- Mask or exclude sensitive fields from logs
- Use user IDs instead of personal information
- Implement proper access controls in Datadog
- Regular review of logged data for compliance

#### Credential Management
- Store Datadog credentials in secure key management
- Rotate API keys regularly
- Use environment-specific credentials
- Implement principle of least privilege

### Cost Management

<table>
<tr>
<th>Strategy</th>
<th>Implementation</th>
<th>Expected Savings</th>
</tr>
<tr>
<td>Smart Sampling</td>
<td>Environment-specific sampling rates</td>
<td>40-60% on traces</td>
</tr>
<tr>
<td>Log Level Optimization</td>
<td>WARN level in production</td>
<td>50-70% on logs</td>
</tr>
<tr>
<td>Retention Policies</td>
<td>Shorter retention for non-critical data</td>
<td>20-30% on storage</td>
</tr>
<tr>
<td>Tag Optimization</td>
<td>Reduce tag cardinality</td>
<td>15-25% on indexing</td>
</tr>
</table>

---

## Next Steps and Action Items

<ac:structured-macro ac:name="status">
<ac:parameter ac:name="colour">Blue</ac:parameter>
<ac:parameter ac:name="title">SETUP</ac:parameter>
</ac:structured-macro>

### Implementation Checklist

- [ ] **Week 1**: Datadog account setup and API key generation
- [ ] **Week 1**: Environment variable configuration
- [ ] **Week 2**: Application deployment with monitoring enabled
- [ ] **Week 2**: Dashboard creation and customization
- [ ] **Week 3**: Alert configuration and testing
- [ ] **Week 3**: Team training and documentation review
- [ ] **Week 4**: Performance optimization and cost review

### Ongoing Maintenance

<ac:structured-macro ac:name="status">
<ac:parameter ac:name="colour">Green</ac:parameter>
<ac:parameter ac:name="title">MONITOR</ac:parameter>
</ac:structured-macro>

- **Monthly**: Review Datadog usage and costs
- **Quarterly**: Update dashboards and alert thresholds
- **Quarterly**: Review and update documentation
- **Annually**: Comprehensive monitoring strategy review

---

<ac:structured-macro ac:name="info">
<ac:rich-text-body>
<p><strong>Support and Resources:</strong></p>
<ul>
<li>Datadog Documentation: <a href="https://docs.datadoghq.com/">https://docs.datadoghq.com/</a></li>
<li>Azure Chat Repository: <a href="https://github.com/microsoft/azurechat">https://github.com/microsoft/azurechat</a></li>
<li>Internal Support: Contact the AI Platform team via Slack #ai-platform-support</li>
</ul>
</ac:rich-text-body>
</ac:structured-macro>

---

*Last updated: March 2024 | Document version: 1.0 | Maintained by: AI Platform Team*