import { registerOTel } from '@vercel/otel';

import type { RegisterTelemetry } from '../interfaces';

export const registerTelemetry: RegisterTelemetry = (serviceName) => {
  registerOTel({ serviceName });
};
