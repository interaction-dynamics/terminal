import type { NotificationProvider } from './interfaces';
import { notificationsEnv } from './env';

export type { Notification, SendNotification } from './interfaces';

export const getProvider = async (): Promise<NotificationProvider> => {
  if (notificationsEnv().SLACK_WEBHOOK_URL) return import('./slack');
  return import('./blank');
};

const provider = await getProvider();

export const { sendNotification } = provider;
