'use client';

import type { User } from '@ship-it/entities';
import { Ban, Ellipsis, ShieldCheck, ShieldOff, Trash2, UserCheck } from 'lucide-react';
import { type ReactNode, useState, useTransition } from 'react';
import { useTranslations } from '@/adapters/translation';
import { Button } from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { type AdminActionResult, changeUserBlocked, changeUserRole, deleteUser } from '../actions';

interface UserActionsProps {
  user: Pick<User, 'id' | 'email' | 'role' | 'blocked'>;
}

/** Translations with string parameters come back as strings; attributes and dialogs need one. */
const asText = (node: ReactNode, fallback: string) => (typeof node === 'string' ? node : fallback);

export function UserActions({ user }: UserActionsProps) {
  const { t } = useTranslations('admin');
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<AdminActionResult['error']>();

  const run = (action: () => Promise<AdminActionResult>) => {
    startTransition(async () => {
      setError((await action()).error);
    });
  };

  const remove = () => {
    if (window.confirm(asText(t('actions.confirmRemove', { email: user.email }), user.email))) {
      run(() => deleteUser(user.id));
    }
  };

  return (
    <div className="flex items-center justify-end gap-2">
      {error && (
        <p role="alert" className="text-xs text-red-600 dark:text-red-400">
          {t(`errors.${error}`)}
        </p>
      )}
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button
            variant="ghost"
            size="icon"
            disabled={pending}
            aria-label={asText(t('actions.menu', { email: user.email }), user.email)}
          >
            <Ellipsis />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          {user.role === 'admin' ? (
            <DropdownMenuItem onSelect={() => run(() => changeUserRole(user.id, 'user'))}>
              <ShieldOff />
              {t('actions.makeUser')}
            </DropdownMenuItem>
          ) : (
            <DropdownMenuItem onSelect={() => run(() => changeUserRole(user.id, 'admin'))}>
              <ShieldCheck />
              {t('actions.makeAdmin')}
            </DropdownMenuItem>
          )}
          {user.blocked ? (
            <DropdownMenuItem onSelect={() => run(() => changeUserBlocked(user.id, false))}>
              <UserCheck />
              {t('actions.unblock')}
            </DropdownMenuItem>
          ) : (
            <DropdownMenuItem onSelect={() => run(() => changeUserBlocked(user.id, true))}>
              <Ban />
              {t('actions.block')}
            </DropdownMenuItem>
          )}
          <DropdownMenuSeparator />
          <DropdownMenuItem
            onSelect={remove}
            className="text-red-600 focus:text-red-700 dark:text-red-400 dark:focus:text-red-300 [&_svg:not([class*='text-'])]:text-current"
          >
            <Trash2 />
            {t('actions.remove')}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );
}
