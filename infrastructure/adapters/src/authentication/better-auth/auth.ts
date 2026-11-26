import { betterAuth } from 'better-auth/minimal';
import { drizzleAdapter } from 'better-auth/adapters/drizzle';
import { admin } from 'better-auth/plugins/admin';
import { createAccessControl } from 'better-auth/plugins/access';
import { emailOTP } from 'better-auth/plugins/email-otp';
import { nextCookies } from 'better-auth/next-js';
import { db, users, sessions, accounts, verifications } from '@ship-it/adapters/database';
import { sendOtpEmail } from './send-otp-email';
import { authenticationEnv } from '../env';

const { BETTER_AUTH_URL, VERCEL_URL } = authenticationEnv();
const baseURL = BETTER_AUTH_URL ?? (VERCEL_URL ? `https://${VERCEL_URL}` : undefined);

// Only what the admin panel needs. The plugin's default admin role can also impersonate users and
// set passwords; those endpoints are mounted under /api/auth, so they are left out here.
const accessControl = createAccessControl({
  user: ['list', 'get', 'set-role', 'ban', 'delete'],
  session: ['revoke'],
});

const roles = {
  admin: accessControl.newRole({
    user: ['list', 'get', 'set-role', 'ban', 'delete'],
    session: ['revoke'],
  }),
  user: accessControl.newRole({ user: [], session: [] }),
};

export const auth = betterAuth({
  baseURL,
  database: drizzleAdapter(db, {
    provider: 'pg',
    schema: {
      user: users,
      session: sessions,
      account: accounts,
      verification: verifications,
    },
  }),
  plugins: [
    emailOTP({ sendVerificationOTP: sendOtpEmail }),
    admin({
      ac: accessControl,
      roles,
      defaultRole: 'user',
      adminRoles: ['admin'],
      bannedUserMessage: 'This account has been blocked.',
      // The entity calls a ban a block; map the plugin's fields onto the drizzle schema's names.
      schema: {
        user: {
          fields: { banned: 'blocked', banReason: 'blockReason', banExpires: 'blockExpiresAt' },
        },
      },
    }),
    nextCookies(),
  ],
});
