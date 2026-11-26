import { NextResponse, type NextProxy } from 'next/server';
import type { AuthAdapterConfig } from './config';

function isProtectedRoute(pathname: string, protectedRoutes: string[]): boolean {
  return protectedRoutes.some((route) => new RegExp(`^${route}`).test(pathname));
}

/**
 * Sends requests for protected routes to the login page unless `hasSession` confirms a session.
 */
export function createProtectedRouteProxy(
  { protectedRoutes }: AuthAdapterConfig,
  hasSession: (headers: Headers) => boolean | Promise<boolean>,
): NextProxy {
  return async (request) => {
    if (!isProtectedRoute(request.nextUrl.pathname, protectedRoutes)) return NextResponse.next();
    if (await hasSession(request.headers)) return NextResponse.next();

    const loginUrl = new URL('/login', request.url);
    loginUrl.searchParams.set('redirect_url', request.nextUrl.pathname);
    return NextResponse.redirect(loginUrl);
  };
}
