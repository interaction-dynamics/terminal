'use server';

import { sendNotification } from '@ship-it/adapters/notifications';
import { getProductName } from '@/config/project';

export async function sendTestNotification(): Promise<{ success: boolean; error?: string }> {
  try {
    await sendNotification({
      title: 'Test Notification',
      message: `This is a test notification sent from ${getProductName()}.`,
    });
    return { success: true };
  } catch (error) {
    return { success: false, error: error instanceof Error ? error.message : 'Unknown error' };
  }
}
