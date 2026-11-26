import type { User, UserRole } from '@ship-it/entities';
import type { NextProxy } from 'next/server';
import type { PropsWithChildren } from 'react';

type AsyncOrSync<T> = T | Promise<T>;

/**
 * Admin-only operations on users. Each one rejects with a `UserAdministrationError`:
 * `forbidden` unless the caller is a signed-in admin, `self` when an admin targets their own
 * account, and `not-found` when no user has the id.
 */
export interface UserAdministration {
  /** Every user, newest first. */
  listUsers: () => Promise<User[]>;
  setUserRole: (userId: string, role: UserRole) => Promise<void>;
  /** Ends the user's sessions and stops them signing in until they are unblocked. */
  blockUser: (userId: string) => Promise<void>;
  unblockUser: (userId: string) => Promise<void>;
  /** Deletes the user together with their sessions and sign-in accounts. */
  removeUser: (userId: string) => Promise<void>;
}

export interface Authentication extends UserAdministration {
  authProxy: () => NextProxy | null;
  SignedIn: (props: PropsWithChildren) => AsyncOrSync<React.ReactNode>;
  SignedOut: (props: PropsWithChildren) => AsyncOrSync<React.ReactNode>;
  AuthenticationProvider: (p: { children: React.ReactNode }) => AsyncOrSync<React.JSX.Element>;
  RedirectToSignIn: React.FC;
  LoginForm: (props: { redirectTo?: string }) => React.ReactNode;
  signIn: (provider?: string, options?: { redirectTo?: string }) => Promise<void>;
  signOut: (options?: { redirectTo?: string }) => Promise<void>;
  isAdmin: () => Promise<boolean>;
  /** The signed-in user, or `null` for an anonymous visitor. */
  getCurrentUser: () => Promise<User | null>;
}
