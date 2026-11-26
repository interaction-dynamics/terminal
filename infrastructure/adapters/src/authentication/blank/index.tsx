import type { NextProxy } from 'next/server';
import type { AuthAdapterConfig } from '../config';
import { UserAdministrationError } from '../errors';
import type { Authentication } from '../interfaces';
import { createProtectedRouteProxy } from '../protected-route';

const refuse = async (): Promise<never> => {
  throw new UserAdministrationError('unavailable');
};

export function createBlankAdapter(config: AuthAdapterConfig): Authentication {
  return {
    // Nobody can have a session without a provider. The proxy must still block these routes:
    // a layout hiding its children does not stop the page rendering into the RSC payload,
    // nor stop its Server Actions running.
    authProxy: (): NextProxy => createProtectedRouteProxy(config, () => false),

    SignedIn() {
      return <p>Not authenticated. Please sign in to access this content.</p>;
    },

    SignedOut({ children }: React.PropsWithChildren) {
      return <>{children}</>;
    },

    RedirectToSignIn() {
      return null;
    },

    LoginForm() {
      return <p>Authentication is not configured.</p>;
    },

    AuthenticationProvider({ children }: React.PropsWithChildren) {
      return <>{children}</>;
    },

    async signIn(): Promise<void> {},

    async signOut(): Promise<void> {},

    async isAdmin(): Promise<boolean> {
      return false;
    },

    async getCurrentUser() {
      return null;
    },

    // Nobody is signed in, so nobody is an admin: every user operation is refused.
    listUsers: refuse,
    setUserRole: refuse,
    blockUser: refuse,
    unblockUser: refuse,
    removeUser: refuse,
  };
}
