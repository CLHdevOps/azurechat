// instrumentation.ts - Next.js 13+ instrumentation file
// This file is automatically loaded by Next.js and runs before any other code

export async function register() {
  // Only initialize Datadog in production or when explicitly enabled
  if (process.env.NODE_ENV === 'production' || process.env.DD_TRACE_ENABLED === 'true') {
    // Import and initialize Datadog tracing
    const { initializeDatadog } = await import('./lib/datadog');
    initializeDatadog();
  }
}