import { forbidden } from 'next/navigation';
import { isAdmin } from '@/adapters/authentication';
import { getTranslations } from '@/adapters/translation';
import { Section } from '@/components/section';
import { UsersTable } from './_components/users-table';

export default async function AdminPage() {
  if (!(await isAdmin())) {
    forbidden();
  }

  const { t } = await getTranslations('admin');

  return (
    <Section title={t('title')}>
      <p className="pb-6 text-neutral-500 dark:text-neutral-400">{t('description')}</p>
      <UsersTable />
    </Section>
  );
}
