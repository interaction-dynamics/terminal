import { getCurrentUser, listUsers } from '@/adapters/authentication';
import { getTranslations } from '@/adapters/translation';
import { Badge } from '@/components/ui/badge';
import {
  Table,
  TableBody,
  TableCaption,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { formatDatetime } from '@/lib/format-datetime';
import { UserActions } from './user-actions';

export async function UsersTable() {
  const [{ t }, users, currentUser] = await Promise.all([
    getTranslations('admin'),
    listUsers(),
    getCurrentUser(),
  ]);

  if (users.length === 0) return <p>{t('empty')}</p>;

  const rows = await Promise.all(
    users.map(async (user) => ({ user, joined: await formatDatetime(user.createdAt) })),
  );

  return (
    <Table>
      <TableCaption>{t('count', { count: String(users.length) })}</TableCaption>
      <TableHeader>
        <TableRow>
          <TableHead>{t('columns.name')}</TableHead>
          <TableHead>{t('columns.email')}</TableHead>
          <TableHead>{t('columns.role')}</TableHead>
          <TableHead>{t('columns.status')}</TableHead>
          <TableHead>{t('columns.joined')}</TableHead>
          <TableHead className="text-right">{t('columns.actions')}</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {rows.map(({ user, joined }) => {
          const isCurrentUser = user.id === currentUser?.id;

          return (
            <TableRow key={user.id}>
              <TableCell className="font-medium">{user.name || '—'}</TableCell>
              <TableCell>{user.email}</TableCell>
              <TableCell>
                <Badge variant={user.role === 'admin' ? 'default' : 'secondary'}>
                  {t(`roles.${user.role}`)}
                </Badge>
              </TableCell>
              <TableCell>
                <Badge variant={user.blocked ? 'destructive' : 'outline'}>
                  {t(user.blocked ? 'status.blocked' : 'status.active')}
                </Badge>
              </TableCell>
              <TableCell>{joined}</TableCell>
              <TableCell className="text-right">
                {/* The adapter refuses self-administration, so an admin cannot lock themselves out. */}
                {isCurrentUser ? (
                  <span className="text-neutral-500 dark:text-neutral-400">{t('you')}</span>
                ) : (
                  <UserActions user={user} />
                )}
              </TableCell>
            </TableRow>
          );
        })}
      </TableBody>
    </Table>
  );
}
