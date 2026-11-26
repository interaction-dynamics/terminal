'use server';

import { sendEmail } from '@ship-it/adapters/email';

export async function sendTestEmail() {
  await sendEmail({
    to: ['daneel09@gmail.com'],
    subject: 'Test Email',
    text: 'This is a test email.',
    html: '<p>This is a test email.</p>',
  });
}
