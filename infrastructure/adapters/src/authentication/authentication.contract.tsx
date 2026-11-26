import { NextRequest, type NextFetchEvent } from 'next/server';
import type { ReactElement, ReactNode } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { User } from '@ship-it/entities';
import type { AuthAdapterConfig, LoginFormComponentProps } from './config';
import { isUserAdministrationError, type UserAdministrationErrorCode } from './errors';
import type { Authentication, UserAdministration } from './interfaces';

/** The parts of a user the contract sets up and reads back. */
export type ContractUser = Pick<User, 'id' | 'email' | 'name' | 'role' | 'blocked'>;

export interface AuthenticationContractHarness {
  /** Sets the env vars and SDK mock defaults the vendor needs. Runs before each test. */
  configure: () => void;
  /** Imports a fresh copy of the adapter and builds it from `config`. */
  load: (config: AuthAdapterConfig) => Promise<Authentication>;
  /** Makes the mocked SDK report this signed-in user on every request, or nobody for `null`. */
  signInAs: (user: { id?: string; role: 'admin' | 'user' } | null) => void;
  /** Replaces the users the mocked SDK stores. */
  seedUsers: (users: ContractUser[]) => void;
  /** The users the mocked SDK stores now. */
  storedUsers: () => ContractUser[];
  /** Makes the mocked SDK fail to look the session up, as when its database is unreachable. */
  failSessionLookup: () => void;
  /** Whether the mocked SDK was asked to end the session. */
  sessionEnded: () => boolean;
  /** Where the user was sent after signing out, if anywhere. */
  signOutRedirect: () => string | undefined;
}

const LoginFormComponent = (_props: LoginFormComponentProps) => null;

const config: AuthAdapterConfig = { protectedRoutes: ['/dashboard(.*)'], LoginFormComponent };

const isRedirect = (status: number) => status >= 300 && status < 400;

/** Whether the proxy let the request reach the page. A rejected proxy serves nothing. */
const reachesPage = async (adapter: Authentication, pathname: string) => {
  const request = new NextRequest(`https://app.test${pathname}`);
  try {
    const response = await adapter.authProxy()?.(request, {} as NextFetchEvent);
    return !response || response.status < 300;
  } catch {
    return false;
  }
};

const loginRedirect = async (adapter: Authentication, pathname: string) => {
  const request = new NextRequest(`https://app.test${pathname}`);
  const response = await adapter.authProxy()?.(request, {} as NextFetchEvent);
  if (!response || !isRedirect(response.status)) return null;
  return new URL(response.headers.get('location') ?? '').pathname;
};

const rejectionCode = async (operation: Promise<unknown>) => {
  try {
    await operation;
  } catch (error) {
    return isUserAdministrationError(error) ? error.code : error;
  }
  return 'resolved';
};

const admin: ContractUser = {
  id: 'admin-1',
  email: 'admin@example.com',
  name: 'Ada',
  role: 'admin',
  blocked: false,
};
const member: ContractUser = {
  id: 'user-2',
  email: 'member@example.com',
  name: 'Grace',
  role: 'user',
  blocked: false,
};
const blockedMember: ContractUser = {
  id: 'user-3',
  email: 'blocked@example.com',
  name: 'Linus',
  role: 'user',
  blocked: true,
};

/** Every admin operation, aimed at `userId`. */
const administrations = (
  adapter: UserAdministration,
  userId: string,
): [string, () => Promise<unknown>][] => [
  ['listUsers', () => adapter.listUsers()],
  ['setUserRole', () => adapter.setUserRole(userId, 'admin')],
  ['blockUser', () => adapter.blockUser(userId)],
  ['unblockUser', () => adapter.unblockUser(userId)],
  ['removeUser', () => adapter.removeUser(userId)],
];

const render = async (node: ReactNode | Promise<ReactNode>) =>
  renderToStaticMarkup(<>{await node}</>);

/**
 * Behaviour every `Authentication` vendor must share so feature code can swap them.
 * Call it from `<vendor>/<vendor>.contract.test.tsx` with the vendor SDK mocked.
 */
export function describeAuthenticationContract(
  vendor: string,
  harness: AuthenticationContractHarness,
): void {
  const signInAsAdmin = async () => {
    harness.signInAs({ id: admin.id, role: 'admin' });
    return harness.load(config);
  };

  const stored = (id: string) => harness.storedUsers().find((user) => user.id === id);

  describe(`${vendor} authentication adapter contract`, () => {
    beforeEach(() => {
      vi.resetModules();
      harness.configure();
    });

    afterEach(() => {
      vi.unstubAllEnvs();
      vi.resetAllMocks();
    });

    describe('proxy', () => {
      it('sends anonymous visitors of a protected route to the login page', async () => {
        harness.signInAs(null);
        const adapter = await harness.load(config);

        await expect(loginRedirect(adapter, '/dashboard/settings')).resolves.toBe('/login');
      });

      it('lets signed-in users reach a protected route', async () => {
        harness.signInAs({ role: 'user' });
        const adapter = await harness.load(config);

        await expect(reachesPage(adapter, '/dashboard/settings')).resolves.toBe(true);
      });

      it('lets anonymous visitors reach public routes', async () => {
        harness.signInAs(null);
        const adapter = await harness.load(config);

        await expect(reachesPage(adapter, '/pricing')).resolves.toBe(true);
      });

      it('matches protected routes from the start of the path', async () => {
        harness.signInAs(null);
        const adapter = await harness.load(config);

        await expect(reachesPage(adapter, '/blog/dashboard-tips')).resolves.toBe(true);
      });

      it('does not serve a protected route when the session cannot be checked', async () => {
        harness.failSessionLookup();
        const adapter = await harness.load(config);

        await expect(reachesPage(adapter, '/dashboard/settings')).resolves.toBe(false);
      });
    });

    describe('SignedIn and SignedOut', () => {
      it('show their children only to signed-in and anonymous visitors respectively', async () => {
        harness.signInAs({ role: 'user' });
        const signedIn = await harness.load(config);
        expect(await render(signedIn.SignedIn({ children: 'members' }))).toContain('members');
        expect(await render(signedIn.SignedOut({ children: 'guests' }))).not.toContain('guests');

        harness.signInAs(null);
        const anonymous = await harness.load(config);
        expect(await render(anonymous.SignedIn({ children: 'members' }))).not.toContain('members');
        expect(await render(anonymous.SignedOut({ children: 'guests' }))).toContain('guests');
      });
    });

    describe('isAdmin', () => {
      it.each([
        ['an admin', { role: 'admin' as const }, true],
        ['a regular user', { role: 'user' as const }, false],
        ['an anonymous visitor', null, false],
      ])('is true only for an admin: %s → %s', async (_who, user, expected) => {
        harness.signInAs(user);
        const { isAdmin } = await harness.load(config);

        await expect(isAdmin()).resolves.toBe(expected);
      });

      it('does not grant admin when the session cannot be checked', async () => {
        harness.failSessionLookup();
        const { isAdmin } = await harness.load(config);

        await expect(isAdmin().catch(() => false)).resolves.toBe(false);
      });
    });

    describe('getCurrentUser', () => {
      it('returns the signed-in user with their role, and null for anonymous visitors', async () => {
        harness.signInAs({ id: admin.id, role: 'admin' });
        const signedIn = await harness.load(config);
        await expect(signedIn.getCurrentUser()).resolves.toMatchObject({
          id: admin.id,
          role: 'admin',
          blocked: false,
        });

        harness.signInAs(null);
        const anonymous = await harness.load(config);
        await expect(anonymous.getCurrentUser()).resolves.toBeNull();
      });
    });

    describe('user administration', () => {
      beforeEach(() => {
        harness.seedUsers([admin, member, blockedMember]);
      });

      it('lists every user with their role and whether they are blocked', async () => {
        const adapter = await signInAsAdmin();

        const users = await adapter.listUsers();

        expect(users).toHaveLength(3);
        expect(users).toEqual(
          expect.arrayContaining([
            expect.objectContaining(admin),
            expect.objectContaining(member),
            expect.objectContaining(blockedMember),
          ]),
        );
      });

      it.each([
        ['a regular user', { id: member.id, role: 'user' as const }],
        ['an anonymous visitor', null],
      ])('refuses every operation to %s and changes nothing', async (_who, user) => {
        harness.signInAs(user);
        const adapter = await harness.load(config);

        const codes = await Promise.all(
          administrations(adapter, blockedMember.id).map(([, operation]) =>
            rejectionCode(operation()),
          ),
        );

        expect(codes).toEqual(codes.map(() => 'forbidden'));
        expect(harness.storedUsers()).toEqual([admin, member, blockedMember]);
      });

      it('changes the role of a user', async () => {
        const adapter = await signInAsAdmin();

        await adapter.setUserRole(member.id, 'admin');
        expect(stored(member.id)?.role).toBe('admin');

        await adapter.setUserRole(member.id, 'user');
        expect(stored(member.id)?.role).toBe('user');
      });

      it('blocks and unblocks a user', async () => {
        const adapter = await signInAsAdmin();

        await adapter.blockUser(member.id);
        expect(stored(member.id)?.blocked).toBe(true);

        await adapter.unblockUser(member.id);
        expect(stored(member.id)?.blocked).toBe(false);
      });

      it('removes a user', async () => {
        const adapter = await signInAsAdmin();

        await adapter.removeUser(member.id);

        expect(stored(member.id)).toBeUndefined();
        expect(harness.storedUsers()).toHaveLength(2);
      });

      it('refuses to let an admin act on their own account', async () => {
        const adapter = await signInAsAdmin();

        const codes = await Promise.all(
          administrations(adapter, admin.id)
            .filter(([name]) => name !== 'listUsers')
            .map(([, operation]) => rejectionCode(operation())),
        );

        expect(codes).toEqual(['self', 'self', 'self', 'self']);
        expect(stored(admin.id)).toEqual(admin);
      });

      it.each(['setUserRole', 'blockUser', 'unblockUser', 'removeUser'])(
        'reports an unknown user to %s as not found',
        async (name) => {
          const adapter = await signInAsAdmin();
          const operation = administrations(adapter, 'missing').find(([n]) => n === name)?.[1];

          await expect(
            rejectionCode(operation?.() ?? Promise.resolve()),
          ).resolves.toBe<UserAdministrationErrorCode>('not-found');
        },
      );
    });

    describe('LoginForm', () => {
      it('renders the app login form wired to send a sign-in email', async () => {
        const { LoginForm } = await harness.load(config);

        const form = LoginForm({ redirectTo: '/welcome' }) as ReactElement<LoginFormComponentProps>;

        expect(form.type).toBe(LoginFormComponent);
        const anyFunction: unknown = expect.any(Function);
        expect(form.props).toMatchObject({ redirectTo: '/welcome', onSend: anyFunction });
      });

      it('explains that sign-in is unavailable when the app has no login form', async () => {
        const { LoginForm } = await harness.load({ protectedRoutes: config.protectedRoutes });

        expect(await render(LoginForm({}))).toMatch(/not configured/i);
      });
    });

    describe('signOut', () => {
      it('ends the session and sends the user where asked', async () => {
        harness.signInAs({ role: 'user' });
        const { signOut } = await harness.load(config);

        await signOut({ redirectTo: '/goodbye' });

        expect(harness.sessionEnded()).toBe(true);
        expect(harness.signOutRedirect()).toBe('/goodbye');
      });
    });
  });
}
