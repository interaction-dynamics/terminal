import { vi } from 'vitest';
import { describeTelemetryContract } from '../monitoring.contract';

const registerOTel = vi.hoisted(() => vi.fn<(options: { serviceName?: string }) => void>());

vi.mock('@vercel/otel', () => ({ registerOTel }));

describeTelemetryContract('Vercel OTel', {
  load: async () => (await import('./index')).registerTelemetry,
  registeredServices: () => registerOTel.mock.calls.map(([{ serviceName }]) => serviceName),
});
