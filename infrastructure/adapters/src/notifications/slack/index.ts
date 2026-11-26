import type { Notification } from '../interfaces';
import { notificationsEnv } from '../env';

const webhookUrl = notificationsEnv().SLACK_WEBHOOK_URL ?? '';

export async function sendNotification(notification: Notification): Promise<void> {
  const blocks = notification.title
    ? [
        {
          type: 'header',
          text: { type: 'plain_text', text: notification.title },
        },
        {
          type: 'section',
          text: { type: 'mrkdwn', text: notification.message },
        },
      ]
    : [
        {
          type: 'section',
          text: { type: 'mrkdwn', text: notification.message },
        },
      ];

  const body: Record<string, unknown> = { blocks };

  if (notification.channel) {
    body.channel = notification.channel;
  }

  const response = await fetch(webhookUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    throw new Error(`Slack notification failed: ${response.status} ${response.statusText}`);
  }
}
