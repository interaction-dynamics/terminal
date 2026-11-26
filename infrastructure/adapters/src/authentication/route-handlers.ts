import type { NextRequest } from 'next/server';
import { authenticationEnv } from './env';

export interface AuthRouteHandlers {
  GET: (request: NextRequest) => Promise<Response>;
  POST: (request: NextRequest) => Promise<Response>;
}

const notFound = async () => new Response(null, { status: 404 });

/**
 * Route handlers for the authentication API (`/api/auth/[...all]`), from whichever
 * provider is configured, or 404 handlers when none is. Vendor selection lives here
 * so the app never imports a vendor.
 */
export const getRouteHandlers = async (): Promise<AuthRouteHandlers> => {
  if (authenticationEnv().BETTER_AUTH_SECRET) {
    const { handlers } = await import('./better-auth');
    return handlers;
  }

  return { GET: notFound, POST: notFound };
};
