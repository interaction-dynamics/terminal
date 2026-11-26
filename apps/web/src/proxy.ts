import type { NextFetchEvent, NextRequest } from 'next/server';

import { authProxy } from '@/adapters/authentication';
import { logRequest } from '@ship-it/adapters/monitoring/server';

const auth = authProxy();

export async function proxy(request: NextRequest, event: NextFetchEvent) {
  logRequest(request, event);
  return auth?.(request, event);
}

export const config = {
  matcher: [
    // Skip Next.js internals and all static files, unless found in search params
    '/((?!_next|[^?]*\\.(?:html?|css|js(?!on)|jpe?g|webp|png|gif|svg|ttf|woff2?|ico|csv|docx?|xlsx?|zip|webmanifest)).*)',
    // Always run for API routes
    '/(api|trpc)(.*)',
  ],
};
