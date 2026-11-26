import { UserAdministrationError } from '@ship-it/adapters/authentication';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { changeUserBlocked, changeUserRole, deleteUser } from '../actions';

const adapter = vi.hoisted(() => ({
  setUserRole: vi.fn<(userId: string, role: string) => Promise<void>>(),
  blockUser: vi.fn<(userId: string) => Promise<void>>(),
  unblockUser: vi.fn<(userId: string) => Promise<void>>(),
  removeUser: vi.fn<(userId: string) => Promise<void>>(),
}));
const revalidatePath = vi.hoisted(() => vi.fn<(path: string) => void>());

// The real wrapper loads a provider at import time; the actions only need these operations.
vi.mock('@/adapters/authentication', async () => {
  const { isUserAdministrationError } = await import('@ship-it/adapters/authentication');
  return { ...adapter, isUserAdministrationError };
});
vi.mock('next/cache', () => ({ revalidatePath }));

describe('admin actions', () => {
  afterEach(() => {
    vi.resetAllMocks();
    vi.restoreAllMocks();
  });

  it('changes the role of a user and refreshes the admin page', async () => {
    adapter.setUserRole.mockResolvedValue();

    await expect(changeUserRole('user-2', 'admin')).resolves.toEqual({});
    expect(adapter.setUserRole).toHaveBeenCalledWith('user-2', 'admin');
    expect(revalidatePath).toHaveBeenCalledWith('/admin');
  });

  it('blocks or unblocks a user', async () => {
    adapter.blockUser.mockResolvedValue();
    adapter.unblockUser.mockResolvedValue();

    await changeUserBlocked('user-2', true);
    await changeUserBlocked('user-3', false);

    expect(adapter.blockUser).toHaveBeenCalledWith('user-2');
    expect(adapter.unblockUser).toHaveBeenCalledWith('user-3');
  });

  it('removes a user', async () => {
    adapter.removeUser.mockResolvedValue();

    await expect(deleteUser('user-2')).resolves.toEqual({});
    expect(adapter.removeUser).toHaveBeenCalledWith('user-2');
  });

  it('rejects input a client could forge, without calling the adapter', async () => {
    // Server Actions are public endpoints, so their arguments arrive unchecked.
    await expect(changeUserRole('user-2', 'owner' as 'admin')).resolves.toEqual({
      error: 'invalid',
    });
    await expect(changeUserBlocked('', true)).resolves.toEqual({ error: 'invalid' });
    await expect(deleteUser(42 as unknown as string)).resolves.toEqual({ error: 'invalid' });

    expect(adapter.setUserRole).not.toHaveBeenCalled();
    expect(adapter.blockUser).not.toHaveBeenCalled();
    expect(adapter.removeUser).not.toHaveBeenCalled();
  });

  it.each(['forbidden', 'self', 'not-found'] as const)(
    'reports a refusal (%s) without refreshing the page',
    async (code) => {
      adapter.removeUser.mockRejectedValue(new UserAdministrationError(code));

      await expect(deleteUser('user-2')).resolves.toEqual({ error: code });
      expect(revalidatePath).not.toHaveBeenCalled();
    },
  );

  it('logs an unexpected failure and reports it without details', async () => {
    const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});
    const cause = new Error('database unreachable');
    adapter.blockUser.mockRejectedValue(cause);

    await expect(changeUserBlocked('user-2', true)).resolves.toEqual({ error: 'unknown' });
    expect(consoleError).toHaveBeenCalledWith('User administration failed:', cause);
  });
});
