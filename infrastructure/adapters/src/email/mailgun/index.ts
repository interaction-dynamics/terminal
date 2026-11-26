import { render, toPlainText } from '@react-email/components';
import formData from 'form-data';
import Mailgun from 'mailgun.js';
import type { Email, FormattedEmail } from '../interfaces';
import { emailEnv } from '../env';

/**
 * @see https://documentation.mailgun.com/docs/mailgun/sdk/nodejs_sdk/
 */
const mailgun = new Mailgun(formData);

let mg: ReturnType<typeof mailgun.client> | null = null;

const client = () => {
  if (!mg) {
    mg = mailgun.client({
      username: 'api',
      key: emailEnv().MAILGUN_API_KEY ?? '',
    });
  }

  return mg;
};

export async function sendEmail(email: Email): Promise<void> {
  const { MAILGUN_DOMAIN: domain, MAILGUN_EMAIL_FROM } = emailEnv();
  if (!domain) {
    throw new Error('MAILGUN_DOMAIN is required to send email with Mailgun.');
  }

  await client().messages.create(domain, {
    from: email.from || MAILGUN_EMAIL_FROM || `postmaster@${domain}`,
    to: email.to,
    subject: email.subject,
    text: email.text,
    html: email.html,
  });
}

export async function sendFormattedEmail({ react, ...email }: FormattedEmail): Promise<void> {
  const html = await render(react);

  await sendEmail({ ...email, html, text: toPlainText(html) });
}
