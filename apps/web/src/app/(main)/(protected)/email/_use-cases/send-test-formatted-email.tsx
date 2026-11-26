'use server';

import { sendFormattedEmail } from '@ship-it/adapters/email';
import { WelcomeEmail } from '../_components/welcome-email';

export async function sendTestFormattedEmail() {
  await sendFormattedEmail({
    to: ['thibault.friedrich@gmail.com'],
    subject: 'Test',
    react: <WelcomeEmail url="" />,
  });
}
