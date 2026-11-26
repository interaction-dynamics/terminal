---
feature: true
# TODO: owner
creation_date: 2026-04-02
---

# Notifications

Lets a signed-in user send a test notification through the configured provider.

## How it works

- `/notifications` (`page.tsx`) renders `NotificationButton` (`_components/`).
- The button calls the `sendTestNotification` Server Action (`_use-cases/`), which uses the notifications adapter (`@ship-it/adapters/notifications`); `SLACK_WEBHOOK_URL` routes notifications to Slack.
