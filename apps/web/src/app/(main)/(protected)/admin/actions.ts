'use server';

import { UserRole } from '@ship-it/entities';
import { revalidatePath } from 'next/cache';
import { z } from 'zod';
import {
  blockUser,
  isUserAdministrationError,
  removeUser,
  setUserRole,
  unblockUser,
  type UserAdministrationErrorCode,
} from '@/adapters/authentication';

export type AdminActionResult = {
  error?: UserAdministrationErrorCode | 'invalid' | 'unknown';
};

const UserId = z.string().min(1);

// Server Actions are public endpoints: the authentication adapter refuses every one of these
// unless the caller is a signed-in admin, so the page guard is not the only check.
async function administer(operation: () => Promise<void>): Promise<AdminActionResult> {
  try {
    await operation();
  } catch (error) {
    if (isUserAdministrationError(error)) return { error: error.code };
    console.error('User administration failed:', error);
    return { error: 'unknown' };
  }

  revalidatePath('/admin');
  return {};
}

export async function changeUserRole(userId: string, role: UserRole): Promise<AdminActionResult> {
  const input = z.object({ userId: UserId, role: UserRole }).safeParse({ userId, role });
  if (!input.success) return { error: 'invalid' };

  return administer(() => setUserRole(input.data.userId, input.data.role));
}

export async function changeUserBlocked(
  userId: string,
  blocked: boolean,
): Promise<AdminActionResult> {
  const input = z.object({ userId: UserId, blocked: z.boolean() }).safeParse({ userId, blocked });
  if (!input.success) return { error: 'invalid' };

  const { userId: id } = input.data;
  return administer(() => (input.data.blocked ? blockUser(id) : unblockUser(id)));
}

export async function deleteUser(userId: string): Promise<AdminActionResult> {
  const input = UserId.safeParse(userId);
  if (!input.success) return { error: 'invalid' };

  return administer(() => removeUser(input.data));
}
