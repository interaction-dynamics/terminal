import { registerTelemetry } from '@ship-it/adapters/monitoring/telemetry';
import { env } from '@/config/env';

export function register() {
  registerTelemetry(env.TELEMETRY_PROJECT);
}

export { onRequestError } from '@ship-it/adapters/monitoring/server';
