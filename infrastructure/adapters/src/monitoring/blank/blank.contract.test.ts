import { vi, type MockInstance } from 'vitest';
import { describeErrorLoggingContract } from '../monitoring.contract';

// With no vendor configured, errors still reach the server logs through the console.
let consoleError: MockInstance<typeof console.error>;

describeErrorLoggingContract('Blank (console)', {
  configure: () => {
    consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});
  },
  load: () => import('./index'),
  logged: () =>
    consoleError.mock.calls.map(([message, error]: unknown[]) => ({
      message: String(message),
      error,
    })),
});
