import { Section } from '@/components/section';
import { NotificationButton } from './_components/notification-button';

export default function NotificationsPage() {
  return (
    <Section title="Notifications">
      <p className="py-10">
        Send a test notification using the configured provider. Set{' '}
        <code className="rounded bg-muted px-1 py-0.5 text-sm">SLACK_WEBHOOK_URL</code> to route
        notifications to Slack.
      </p>
      <NotificationButton />
    </Section>
  );
}
