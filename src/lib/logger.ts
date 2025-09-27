import { tracer } from './datadog';

// Log levels enum
export enum LogLevel {
  DEBUG = 'debug',
  INFO = 'info',
  WARN = 'warn',
  ERROR = 'error'
}

// Base log entry interface
interface BaseLogEntry {
  timestamp: string;
  level: LogLevel;
  message: string;
  service: string;
  environment: string;
  version: string;
  dd?: {
    trace_id?: string;
    span_id?: string;
  };
}

// Extended log entry with custom metadata
interface LogEntry extends BaseLogEntry {
  [key: string]: any;
}

// Logger configuration
interface LoggerConfig {
  service?: string;
  environment?: string;
  version?: string;
  enableConsole?: boolean;
  enableDatadog?: boolean;
}

class Logger {
  private config: LoggerConfig;

  constructor(config: LoggerConfig = {}) {
    this.config = {
      service: config.service || process.env.DD_SERVICE || 'azurechat',
      environment: config.environment || process.env.DD_ENV || process.env.NODE_ENV || 'development',
      version: config.version || process.env.DD_VERSION || '1.0.0',
      enableConsole: config.enableConsole !== false,
      enableDatadog: config.enableDatadog !== false
    };
  }

  private createLogEntry(level: LogLevel, message: string, metadata: Record<string, any> = {}): LogEntry {
    const span = tracer.scope().active();
    const timestamp = new Date().toISOString();

    const logEntry: LogEntry = {
      timestamp,
      level,
      message,
      service: this.config.service!,
      environment: this.config.environment!,
      version: this.config.version!,
      ...metadata
    };

    // Add Datadog trace correlation if available
    if (span && this.config.enableDatadog) {
      logEntry.dd = {
        trace_id: span.context().toTraceId(),
        span_id: span.context().toSpanId()
      };
    }

    return logEntry;
  }

  private output(logEntry: LogEntry): void {
    if (this.config.enableConsole) {
      const logString = JSON.stringify(logEntry, null, process.env.NODE_ENV === 'development' ? 2 : undefined);

      // Use appropriate console method based on log level
      switch (logEntry.level) {
        case LogLevel.ERROR:
          console.error(logString);
          break;
        case LogLevel.WARN:
          console.warn(logString);
          break;
        case LogLevel.DEBUG:
          console.debug(logString);
          break;
        default:
          console.log(logString);
      }
    }
  }

  debug(message: string, metadata?: Record<string, any>): void {
    const logEntry = this.createLogEntry(LogLevel.DEBUG, message, metadata);
    this.output(logEntry);
  }

  info(message: string, metadata?: Record<string, any>): void {
    const logEntry = this.createLogEntry(LogLevel.INFO, message, metadata);
    this.output(logEntry);
  }

  warn(message: string, metadata?: Record<string, any>): void {
    const logEntry = this.createLogEntry(LogLevel.WARN, message, metadata);
    this.output(logEntry);
  }

  error(message: string, error?: Error | unknown, metadata?: Record<string, any>): void {
    const logMetadata = { ...metadata };

    if (error) {
      if (error instanceof Error) {
        logMetadata.error = {
          name: error.name,
          message: error.message,
          stack: error.stack
        };
      } else {
        logMetadata.error = {
          details: String(error)
        };
      }
    }

    const logEntry = this.createLogEntry(LogLevel.ERROR, message, logMetadata);
    this.output(logEntry);
  }

  // Specialized logging methods for Azure Chat application

  chatEvent(action: string, metadata: Record<string, any> = {}): void {
    this.info(`Chat event: ${action}`, {
      category: 'chat',
      action,
      ...metadata
    });
  }

  azureOpenAI(action: string, metadata: Record<string, any> = {}): void {
    this.info(`Azure OpenAI: ${action}`, {
      category: 'azure_openai',
      action,
      ...metadata
    });
  }

  azureService(service: string, action: string, metadata: Record<string, any> = {}): void {
    this.info(`Azure ${service}: ${action}`, {
      category: 'azure_service',
      service,
      action,
      ...metadata
    });
  }

  userAction(action: string, userId?: string, metadata: Record<string, any> = {}): void {
    this.info(`User action: ${action}`, {
      category: 'user_action',
      action,
      userId: userId || 'anonymous',
      ...metadata
    });
  }

  fileOperation(operation: string, fileName: string, metadata: Record<string, any> = {}): void {
    this.info(`File operation: ${operation}`, {
      category: 'file_operation',
      operation,
      fileName,
      ...metadata
    });
  }

  authEvent(event: string, userId?: string, metadata: Record<string, any> = {}): void {
    this.info(`Auth event: ${event}`, {
      category: 'authentication',
      event,
      userId: userId || 'anonymous',
      ...metadata
    });
  }

  performance(operation: string, duration: number, metadata: Record<string, any> = {}): void {
    this.info(`Performance: ${operation}`, {
      category: 'performance',
      operation,
      duration,
      unit: 'ms',
      ...metadata
    });
  }

  // Create a child logger with additional context
  child(context: Record<string, any>): Logger {
    const childLogger = new Logger(this.config);
    const originalCreateLogEntry = childLogger.createLogEntry.bind(childLogger);

    childLogger.createLogEntry = (level: LogLevel, message: string, metadata: Record<string, any> = {}) => {
      return originalCreateLogEntry(level, message, { ...context, ...metadata });
    };

    return childLogger;
  }
}

// Create and export default logger instance
export const logger = new Logger();

// Export the Logger class for custom instances
export { Logger };

// Utility function to create a logger with specific context
export function createLogger(context: Record<string, any>): Logger {
  return logger.child(context);
}

// Middleware helper for request logging
export function createRequestLogger(req: any): Logger {
  const requestId = req.headers['x-request-id'] || req.headers['x-correlation-id'] || 'unknown';
  const userAgent = req.headers['user-agent'] || 'unknown';
  const ip = req.headers['x-forwarded-for'] || req.connection?.remoteAddress || 'unknown';

  return logger.child({
    requestId,
    userAgent,
    ip,
    method: req.method,
    url: req.url
  });
}