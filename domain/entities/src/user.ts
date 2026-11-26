import { z } from 'zod';

/**
 * The user's status in the application. `admin` unlocks the admin panel, where users are
 * listed, blocked, removed or given another role.
 */
export const UserRole = z.enum(['user', 'admin']);
export type UserRole = z.infer<typeof UserRole>;

export const UserSchema = z.object({
  id: z.string(),
  email: z.email(),
  emailVerified: z.boolean(),
  name: z.string(),
  image: z.string().nullable().optional(),
  role: UserRole.default('user'),
  /** A blocked user cannot sign in, and blocking them ends the sessions they had open. */
  blocked: z.boolean().default(false),
  blockReason: z.string().nullable().optional(),
  /** When the block lifts on its own; `null` keeps the user blocked until an admin unblocks them. */
  blockExpiresAt: z.date().nullable().optional(),
  createdAt: z.date(),
  updatedAt: z.date(),
});

export type User = z.infer<typeof UserSchema>;
