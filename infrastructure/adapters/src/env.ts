/**
 * Environment schemas owned by each capability. Apps compose them into a single validated
 * env (see `apps/web/src/config/env.ts`) so misconfiguration fails at build and boot time.
 */
export { analyticsEnv } from './analytics/env';
export { authenticationEnv } from './authentication/env';
export { databaseEnv } from './database/env';
export { emailEnv } from './email/env';
export { experimentationEnv } from './experimentation/env';
export { monitoringEnv } from './monitoring/env';
export { notificationsEnv } from './notifications/env';
export { paymentEnv } from './payment/env';
