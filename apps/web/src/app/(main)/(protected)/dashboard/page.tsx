import { Users } from 'lucide-react';
import Link from 'next/link';
import { forbidden } from 'next/navigation';
import { isAdmin } from '@/adapters/authentication';
import { getTranslations } from '@/adapters/translation';
import { Section } from '@/components/section';
import { Button } from '@/components/ui/button';

export default async function DashboardPage() {
  if (!(await isAdmin())) {
    forbidden();
  }

  const { t } = await getTranslations('dashboard');

  return (
    <Section title={t('title')}>
      <p>Hello world</p>
      <Button asChild variant="outline" className="mt-6">
        <Link href="/admin">
          <Users />
          {t('manageUsers')}
        </Link>
      </Button>
    </Section>
  );
}
