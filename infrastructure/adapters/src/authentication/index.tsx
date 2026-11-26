import type { Authentication } from './interfaces';
import type { AuthAdapterConfig } from './config';
import { authenticationEnv } from './env';

export type { Authentication, UserAdministration } from './interfaces';
export {
  UserAdministrationError,
  isUserAdministrationError,
  type UserAdministrationErrorCode,
} from './errors';
export type { ActionResult, AuthAdapterConfig, LoginFormComponentProps } from './config';
export { getRouteHandlers, type AuthRouteHandlers } from './route-handlers';

export const getProvider = async (config: AuthAdapterConfig): Promise<Authentication> => {
  const { BETTER_AUTH_SECRET } = authenticationEnv();

  try {
    if (BETTER_AUTH_SECRET) {
      const { createBetterAuthAdapter } = await import('./better-auth');
      return createBetterAuthAdapter(config);
    }
  } catch (error) {
    // Fail closed: a provider was asked for, so serving the app without it would
    // silently drop the protection the deployment expects.
    throw new Error(
      'The configured authentication provider failed to load. Fix its configuration or unset BETTER_AUTH_SECRET to run without authentication.',
      { cause: error },
    );
  }

  const { createBlankAdapter } = await import('./blank');
  return createBlankAdapter(config);
};
