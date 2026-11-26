import type { Notification } from '../interfaces';

export async function sendNotification(notification: Notification): Promise<void> {
  console.log('[Notifications] blank provider - notification not sent:', notification);
}
