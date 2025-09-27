/** @type {import('next').NextConfig} */
const nextConfig = {
  output: "standalone",
  experimental: {
    serverComponentsExternalPackages: ["@azure/storage-blob", "dd-trace"],
    instrumentationHook: true,
  },
  // Datadog configuration
  env: {
    DD_SERVICE: process.env.DD_SERVICE || 'azurechat',
    DD_ENV: process.env.DD_ENV || process.env.NODE_ENV || 'development',
    DD_VERSION: process.env.DD_VERSION || '1.0.0',
  },
};

module.exports = nextConfig;
