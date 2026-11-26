import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { TranslationProviderClient } from '@/adapters/translation/i18n/_private/context';
import messages from '@/content/messages/en/admin.json';
import type { AdminActionResult } from '../../actions';
import { UserActions } from '../user-actions';

const actions = vi.hoisted(() => ({
  changeUserRole: vi.fn<(userId: string, role: string) => Promise<AdminActionResult>>(),
  changeUserBlocked: vi.fn<(userId: string, blocked: boolean) => Promise<AdminActionResult>>(),
  deleteUser: vi.fn<(userId: string) => Promise<AdminActionResult>>(),
}));

vi.mock('../../actions', () => actions);

const member = { id: 'user-2', email: 'member@example.com', role: 'user', blocked: false } as const;

const renderActions = (user: Parameters<typeof UserActions>[0]['user'] = member) =>
  render(
    <TranslationProviderClient
      locale="en"
      languages={[]}
      messages={{ admin: messages }}
      defaultNamespace="admin"
    >
      <UserActions user={user} />
    </TranslationProviderClient>,
  );

const choose = async (item: string) => {
  // Radix opens the menu from the keyboard; jsdom has no pointer events.
  fireEvent.keyDown(screen.getByRole('button', { name: 'Actions for member@example.com' }), {
    key: 'Enter',
  });
  fireEvent.click(await screen.findByRole('menuitem', { name: item }));
};

describe('UserActions', () => {
  afterEach(() => {
    vi.resetAllMocks();
    vi.restoreAllMocks();
  });

  it('promotes a regular user to admin', async () => {
    actions.changeUserRole.mockResolvedValue({});
    renderActions();

    await choose('Make admin');

    await waitFor(() => expect(actions.changeUserRole).toHaveBeenCalledWith('user-2', 'admin'));
  });

  it('offers to unblock a blocked user', async () => {
    actions.changeUserBlocked.mockResolvedValue({});
    renderActions({ ...member, blocked: true });

    await choose('Unblock');

    await waitFor(() => expect(actions.changeUserBlocked).toHaveBeenCalledWith('user-2', false));
  });

  it('removes a user only once the admin confirms', async () => {
    actions.deleteUser.mockResolvedValue({});
    const confirm = vi
      .spyOn(window, 'confirm')
      .mockReturnValueOnce(false)
      .mockReturnValueOnce(true);
    renderActions();

    await choose('Remove');
    expect(actions.deleteUser).not.toHaveBeenCalled();

    await choose('Remove');
    await waitFor(() => expect(actions.deleteUser).toHaveBeenCalledWith('user-2'));
    expect(confirm).toHaveBeenCalledWith(
      'Remove member@example.com? This deletes the account and cannot be undone.',
    );
  });

  it('shows why an action was refused', async () => {
    actions.changeUserBlocked.mockResolvedValue({ error: 'not-found' });
    renderActions();

    await choose('Block');

    expect(await screen.findByRole('alert')).toHaveTextContent('This user no longer exists.');
  });
});
