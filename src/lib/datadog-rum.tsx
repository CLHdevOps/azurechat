'use client';

import React from 'react';
import { datadogRum } from '@datadog/browser-rum';
import { getRumConfig } from './datadog-config';

// Initialize Datadog RUM only on the client side
export function initializeDatadogRUM() {
  // Only initialize if we're in the browser
  if (typeof window === 'undefined') {
    return;
  }

  const config = getRumConfig();

  // Validate required configuration
  if (!config.applicationId || !config.clientToken) {
    console.log('[Datadog RUM] Disabled - missing applicationId or clientToken');
    return;
  }

  try {
    datadogRum.init({
      applicationId: config.applicationId,
      clientToken: config.clientToken,
      site: config.site,
      service: config.service,
      env: config.env,
      version: config.version,
      sessionSampleRate: getSessionSampleRate(config.env),
      sessionReplaySampleRate: getSessionReplaySampleRate(config.env),
      trackUserInteractions: true,
      trackResources: true,
      trackLongTasks: true,
      defaultPrivacyLevel: 'mask-user-input',
      allowedTracingUrls: [
        // Azure OpenAI endpoints
        { match: /https:\/\/.*\.openai\.azure\.com\/.*/, propagateTracing: true },
        // Azure Cosmos DB endpoints
        { match: /https:\/\/.*\.documents\.azure\.com\/.*/, propagateTracing: true },
        // Azure AI Search endpoints
        { match: /https:\/\/.*\.search\.windows\.net\/.*/, propagateTracing: true },
        // Azure Storage endpoints
        { match: /https:\/\/.*\.blob\.core\.windows\.net\/.*/, propagateTracing: true },
        // Current application origin
        { match: window.location.origin, propagateTracing: true }
      ]
    });

    // Set global context for the entire session
    datadogRum.setGlobalContextProperty('application', {
      name: 'azurechat',
      version: config.version,
      environment: config.env,
      component: 'frontend'
    });

    // Set Azure context if available
    const azureContext = getAzureContext();
    if (azureContext) {
      datadogRum.setGlobalContextProperty('azure', azureContext);
    }

    console.log(`[Datadog RUM] Initialized for service: ${config.service} (env: ${config.env})`);
  } catch (error) {
    console.error('[Datadog RUM] Initialization failed:', error);
  }
}

// Environment-specific sampling rates
function getSessionSampleRate(env: string): number {
  switch (env) {
    case 'production':
      return 50; // 50% sampling in production to manage costs
    case 'staging':
      return 100; // 100% sampling in staging for testing
    default:
      return 100; // 100% sampling in development
  }
}

function getSessionReplaySampleRate(env: string): number {
  switch (env) {
    case 'production':
      return 10; // 10% replay sampling in production
    case 'staging':
      return 20; // 20% replay sampling in staging
    default:
      return 0; // No replay in development by default
  }
}

// Extract Azure context from environment
function getAzureContext(): Record<string, string> | null {
  if (typeof window === 'undefined') return null;

  // Try to extract Azure context from various sources
  const context: Record<string, string> = {};

  // Check if we can get Azure region from headers or meta tags
  const metaRegion = document.querySelector('meta[name="azure-region"]');
  if (metaRegion) {
    context.region = metaRegion.getAttribute('content') || 'unknown';
  }

  // Check if we have Azure subscription ID in meta tags
  const metaSubscription = document.querySelector('meta[name="azure-subscription"]');
  if (metaSubscription) {
    context.subscription_id = metaSubscription.getAttribute('content') || 'unknown';
  }

  return Object.keys(context).length > 0 ? context : null;
}

// Custom event tracking functions
export const datadogRumHelpers = {
  // Track user authentication events
  trackAuth: (action: 'login' | 'logout' | 'signup', userId?: string) => {
    if (typeof window !== 'undefined' && datadogRum) {
      datadogRum.addAction('auth', {
        action,
        userId: userId || 'anonymous',
        timestamp: Date.now()
      });
    }
  },

  // Track chat interactions
  trackChatEvent: (action: 'message_sent' | 'message_received' | 'chat_started' | 'chat_ended', metadata?: Record<string, any>) => {
    if (typeof window !== 'undefined' && datadogRum) {
      datadogRum.addAction('chat', {
        action,
        ...metadata,
        timestamp: Date.now()
      });
    }
  },

  // Track file uploads
  trackFileUpload: (fileName: string, fileSize: number, fileType: string, success: boolean) => {
    if (typeof window !== 'undefined' && datadogRum) {
      datadogRum.addAction('file_upload', {
        fileName,
        fileSize,
        fileType,
        success,
        timestamp: Date.now()
      });
    }
  },

  // Track errors
  trackError: (error: Error, context?: Record<string, any>) => {
    if (typeof window !== 'undefined' && datadogRum) {
      datadogRum.addError(error, context);
    }
  },

  // Track performance timing
  trackTiming: (name: string, duration: number, metadata?: Record<string, any>) => {
    if (typeof window !== 'undefined' && datadogRum) {
      datadogRum.addTiming(name, duration, metadata);
    }
  },

  // Set user context
  setUser: (userId: string, userInfo?: Record<string, any>) => {
    if (typeof window !== 'undefined' && datadogRum) {
      datadogRum.setUser({
        id: userId,
        ...userInfo
      });
    }
  },

  // Add context to current session
  addContext: (key: string, value: any) => {
    if (typeof window !== 'undefined' && datadogRum) {
      datadogRum.setGlobalContextProperty(key, value);
    }
  }
};

// React component to initialize RUM
export function DatadogRumProvider({ children }: { children: React.ReactNode }) {
  // Initialize RUM on component mount
  React.useEffect(() => {
    initializeDatadogRUM();
  }, []);

  return <>{children}</>;
}

// React hook for RUM helpers
export function useDatadogRum() {
  return datadogRumHelpers;
}