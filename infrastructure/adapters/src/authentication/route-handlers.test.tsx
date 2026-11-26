import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { NextRequest } from 'next/server';
import type { AuthRouteHandlers } from './route-handlers';

const betterAuthHandlers = vi.hoisted(() => ({
  GET: vi.fn<AuthRouteHandlers['GET']>(),
  POST: vi.fn<AuthRouteHandlers['POST']>(),
}));

vi.mock('./better-auth', () => ({ handlers: betterAuthHandlers }));

import { getRouteHandlers } from './route-handlers';

describe('authentication getRouteHandlers', () => {
  beforeEach(() => {
    vi.stubEnv('BETTER_AUTH_SECRET', '');
  });

  afterEach(() => {
    vi.unstubAllEnvs();
  });

  it('returns the Better Auth handlers when BETTER_AUTH_SECRET is set', async () => {
    vi.stubEnv('BETTER_AUTH_SECRET', 'secret');

    await expect(getRouteHandlers()).resolves.toBe(betterAuthHandlers);
  });

  it('answers 404 when no provider is configured', async () => {
    const handlers = await getRouteHandlers();
    const request = new NextRequest('https://app.test/api/auth/session');

    expect((await handlers.GET(request)).status).toBe(404);
    expect((await handlers.POST(request)).status).toBe(404);
  });
});
