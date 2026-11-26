import { vi } from 'vitest';
import { describeAuthenticationContract, type ContractUser } from '../authentication.contract';

/** A user as Better Auth's admin plugin returns it. */
interface VendorUser {
  id: string;
  email: string;
  emailVerified: boolean;
  name: string;
  role: string;
  banned: boolean;
  banReason: string | null;
  banExpires: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

const vendor = vi.hoisted(() => ({
  session: null as { user: VendorUser } | null,
  users: [] as VendorUser[],
  lookupFails: false,
  sessionEnded: false,
  redirects: [] as string[],
}));

const toVendorUser = ({ blocked, ...user }: ContractUser, index = 0): VendorUser => ({
  ...user,
  emailVerified: true,
  banned: blocked,
  banReason: blocked ? 'No reason' : null,
  banExpires: null,
  createdAt: new Date(Date.UTC(2026, 0, 1 + index)),
  updatedAt: new Date(Date.UTC(2026, 0, 1 + index)),
});

// `./auth` builds Better Auth on a real database; stand in for the parts the adapter calls.
vi.mock('./auth', async () => {
  const { APIError } = await import('better-auth/api');

  const findUser = (userId: string) => {
    const user = vendor.users.find(({ id }) => id === userId);
    if (!user) throw new APIError('NOT_FOUND', { message: 'User not found' });
    return user;
  };

  return {
    auth: {
      api: {
        getSession: async () => {
          if (vendor.lookupFails) throw new Error('database unreachable');
          return vendor.session;
        },
        signOut: async () => {
          vendor.sessionEnded = true;
        },
        listUsers: async () => ({
          users: vendor.users.toSorted((a, b) => b.createdAt.getTime() - a.createdAt.getTime()),
          total: vendor.users.length,
        }),
        setRole: async ({ body }: { body: { userId: string; role: string } }) => {
          findUser(body.userId).role = body.role;
        },
        banUser: async ({ body }: { body: { userId: string } }) => {
          Object.assign(findUser(body.userId), { banned: true, banReason: 'No reason' });
        },
        unbanUser: async ({ body }: { body: { userId: string } }) => {
          Object.assign(findUser(body.userId), { banned: false, banReason: null });
        },
        removeUser: async ({ body }: { body: { userId: string } }) => {
          findUser(body.userId);
          vendor.users = vendor.users.filter(({ id }) => id !== body.userId);
        },
      },
    },
  };
});
vi.mock('./send-otp-email', () => ({ sendOtpEmail: async () => {} }));
vi.mock('better-auth/next-js', () => ({ toNextJsHandler: () => ({}) }));
vi.mock('next/headers', () => ({ headers: async () => new Headers() }));
vi.mock('next/navigation', () => ({
  redirect: (url: string) => {
    vendor.redirects.push(url);
  },
}));

describeAuthenticationContract('Better Auth', {
  configure: () => {
    Object.assign(vendor, {
      session: null,
      users: [],
      lookupFails: false,
      sessionEnded: false,
      redirects: [],
    });
    vi.stubEnv('BETTER_AUTH_SECRET', 'test-secret');
  },
  load: async (config) => (await import('./index')).createBetterAuthAdapter(config),
  signInAs: (user) => {
    vendor.session = user && {
      user: toVendorUser({
        id: user.id ?? 'user-1',
        email: 'user@example.com',
        name: 'Signed In',
        role: user.role,
        blocked: false,
      }),
    };
  },
  seedUsers: (users) => {
    vendor.users = users.map(toVendorUser);
  },
  storedUsers: () =>
    vendor.users.map(({ id, email, name, role, banned }) => ({
      id,
      email,
      name,
      role: role === 'admin' ? 'admin' : 'user',
      blocked: banned,
    })),
  failSessionLookup: () => {
    vendor.lookupFails = true;
  },
  sessionEnded: () => vendor.sessionEnded,
  signOutRedirect: () => vendor.redirects.at(-1),
});
