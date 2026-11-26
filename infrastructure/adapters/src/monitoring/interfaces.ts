export interface Monitoring {
  logError: (message: string, error: unknown) => void;
  WebVitals: React.FC;
}

export type RegisterTelemetry = (serviceName?: string) => void;
