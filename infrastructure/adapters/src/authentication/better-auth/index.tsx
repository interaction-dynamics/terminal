import type { NextProxy } from 'next/server';
import { headers } from 'next/headers';
import { redirect } from 'next/navigation';
import { isAPIError } from 'better-auth/api';
import { toNextJsHandler } from 'better-auth/next-js';
import { UserRole, UserSchema, type User } from '@ship-it/entities';
import type { Authentication } from '../interfaces';
import type { AuthAdapterConfig } from '../config';
import { UserAdministrationError } from '../errors';
import { createProtectedRouteProxy } from '../protected-route';

import { auth } from './auth';
import { sendOtpEmail } from './send-otp-email';

async function onSend(email: string) {
  'use server';
  try {
    // Not auth.api.sendVerificationOTP: it reports success even when the email fails to send.
    const otp = await auth.api.createVerificationOTP({ body: { email, type: 'sign-in' } });
    await sendOtpEmail({ email, otp, type: 'sign-in' });
    return {};
  } catch (error) {
    console.error('Failed to send verification code:', error);
    return { error: 'Failed to send verification code' };
  }
}

async function onVerify(email: string, otp: string) {
  'use server';
  try {
    await auth.api.signInEmailOTP({ body: { email, otp }, headers: await headers() });
    return {};
  } catch (error) {
    if (isAPIError(error) && error.body?.code === 'BANNED_USER') {
      return { error: 'This account has been blocked' };
    }
    return { error: 'Invalid verification code' };
  }
}

/** The user as Better Auth returns it, with the admin plugin's fields. */
interface VendorUser {
  id: string;
  email: string;
  emailVerified: boolean;
  name: string;
  image?: string | null;
  role?: string | null;
  banned?: boolean | null;
  banReason?: string | null;
  banExpires?: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

function toUser(user: VendorUser): User {
  return UserSchema.parse({
    id: user.id,
    email: user.email,
    emailVerified: user.emailVerified,
    name: user.name,
    image: user.image ?? null,
    // Better Auth allows comma-separated roles; anything but exactly `admin` is a regular user.
    role: UserRole.safeParse(user.role).data ?? 'user',
    blocked: user.banned ?? false,
    blockReason: user.banReason ?? null,
    blockExpiresAt: user.banExpires ?? null,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  });
}

const getSession = async () => auth.api.getSession({ headers: await headers() });

/**
 * Runs an admin operation on another user's account. The plugin checks the role again on its
 * side; checking here first keeps the port's errors the same whatever the vendor reports.
 */
async function administer(
  userId: string,
  operation: (requestHeaders: Headers) => Promise<unknown>,
): Promise<void> {
  const session = await getSession();
  if (session?.user.role !== 'admin') throw new UserAdministrationError('forbidden');
  if (session.user.id === userId) throw new UserAdministrationError('self');

  try {
    await operation(await headers());
  } catch (error) {
    if (isAPIError(error) && error.status === 'NOT_FOUND') {
      throw new UserAdministrationError('not-found', { cause: error });
    }
    if (isAPIError(error) && (error.status === 'FORBIDDEN' || error.status === 'UNAUTHORIZED')) {
      throw new UserAdministrationError('forbidden', { cause: error });
    }
    throw error;
  }
}

export const handlers = toNextJsHandler(auth);

export function createBetterAuthAdapter(config: AuthAdapterConfig): Authentication & {
  handlers: typeof handlers;
} {
  return {
    handlers,

    authProxy(): NextProxy {
      return createProtectedRouteProxy(
        config,
        async (requestHeaders) => !!(await auth.api.getSession({ headers: requestHeaders })),
      );
    },

    async SignedIn({ children }: React.PropsWithChildren) {
      const session = await auth.api.getSession({ headers: await headers() });
      if (!session) return null;
      return <>{children}</>;
    },

    async SignedOut({ children }: React.PropsWithChildren) {
      const session = await auth.api.getSession({ headers: await headers() });
      if (session) return null;
      return <>{children}</>;
    },

    RedirectToSignIn() {
      redirect('/login');
      return <></>;
    },

    LoginForm({ redirectTo = '/dashboard' }: { redirectTo?: string }) {
      const LoginFormComponent = config.LoginFormComponent;
      if (!LoginFormComponent) return <p>Authentication is not configured.</p>;

      return (
        <LoginFormComponent
          variant="otp"
          redirectTo={redirectTo}
          onSend={onSend}
          onVerify={onVerify}
        />
      );
    },

    AuthenticationProvider({ children }: React.PropsWithChildren) {
      return <>{children}</>;
    },

    async signIn(_provider?: string, options?: { redirectTo?: string }): Promise<void> {
      const url = options?.redirectTo ? `/login?redirect_url=${options.redirectTo}` : '/login';
      redirect(url);
    },

    async signOut(options?: { redirectTo?: string }): Promise<void> {
      await auth.api.signOut({ headers: await headers() });
      redirect(options?.redirectTo ?? '/');
    },

    async isAdmin(): Promise<boolean> {
      const session = await getSession();
      return session?.user?.role === 'admin';
    },

    async getCurrentUser(): Promise<User | null> {
      const session = await getSession();
      return session ? toUser(session.user) : null;
    },

    async listUsers(): Promise<User[]> {
      const session = await getSession();
      if (session?.user.role !== 'admin') throw new UserAdministrationError('forbidden');

      const { users } = await auth.api.listUsers({
        query: { sortBy: 'createdAt', sortDirection: 'desc' },
        headers: await headers(),
      });
      return users.map(toUser);
    },

    setUserRole: (userId, role) =>
      administer(userId, (requestHeaders) =>
        auth.api.setRole({ body: { userId, role }, headers: requestHeaders }),
      ),

    blockUser: (userId) =>
      administer(userId, (requestHeaders) =>
        auth.api.banUser({ body: { userId }, headers: requestHeaders }),
      ),

    unblockUser: (userId) =>
      administer(userId, (requestHeaders) =>
        auth.api.unbanUser({ body: { userId }, headers: requestHeaders }),
      ),

    removeUser: (userId) =>
      administer(userId, (requestHeaders) =>
        auth.api.removeUser({ body: { userId }, headers: requestHeaders }),
      ),
  };
}
