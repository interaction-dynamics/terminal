---
feature: true
# TODO: owner
creation_date: 2026-03-06
---

# Email

Lets a signed-in user send a plain and a formatted test email through the configured email provider.

## How it works

- `/email` (`page.tsx`) renders `EmailButton` and `FormattedEmailButton` (`_components/`).
- They call the `sendTestEmail` and `sendTestFormattedEmail` Server Actions (`_use-cases/`), which use the email adapter (`@ship-it/adapters/email`).
- The formatted email is the `WelcomeEmail` React template (`_components/welcome-email.tsx`).
