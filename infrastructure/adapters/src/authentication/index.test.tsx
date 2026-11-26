import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { NextRequest, type NextFetchEvent } from 'next/server';
import type { AuthAdapterConfig } from './config';
import type { Authentication } from './interfaces';

type AdapterFactory = (config: AuthAdapterConfig) => Authentication;

const betterAuthFactory = vi.hoisted(() => vi.fn<AdapterFactory>());

vi.mock('./better-auth', () => ({ createBetterAuthAdapter: betterAuthFactory }));

import { getProvider } from './index';

const config = { protectedRoutes: ['/dashboard(.*)', '/email(.*)'] };

const proxyResponse = async (pathname: string) => {
  const { authProxy } = await getProvider(config);
  return authProxy()?.(new NextRequest(`https://app.test${pathname}`), {} as NextFetchEvent);
};

describe('authentication getProvider', () => {
  beforeEach(() => {
    vi.stubEnv('BETTER_AUTH_SECRET', '');
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    vi.resetAllMocks();
  });

  it('fails closed when BETTER_AUTH_SECRET is set and the provider cannot load', async () => {
    vi.stubEnv('BETTER_AUTH_SECRET', 'secret');
    const cause = new Error('database unreachable');
    betterAuthFactory.mockImplementation(() => {
      throw cause;
    });

    const loading = getProvider(config);
    await expect(loading).rejects.toThrow('failed to load');
    await expect(loading).rejects.toHaveProperty('cause', cause);
  });

  it('returns the configured provider when it loads', async () => {
    vi.stubEnv('BETTER_AUTH_SECRET', 'secret');
    const adapter = {} as Authentication;
    betterAuthFactory.mockReturnValue(adapter);

    await expect(getProvider(config)).resolves.toBe(adapter);
  });

  describe('when no provider is configured', () => {
    it('does not try to load a vendor', async () => {
      await getProvider(config);

      expect(betterAuthFactory).not.toHaveBeenCalled();
    });

    it('redirects protected routes to the login page', async () => {
      const response = await proxyResponse('/email');

      expect(response?.status).toBe(307);
      expect(response?.headers.get('location')).toBe(
        'https://app.test/login?redirect_url=%2Femail',
      );
    });

    it('lets public routes through', async () => {
      const response = await proxyResponse('/pricing');

      expect(response?.headers.get('x-middleware-next')).toBe('1');
    });
  });
});
