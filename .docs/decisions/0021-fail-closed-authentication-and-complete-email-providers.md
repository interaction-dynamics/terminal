# Fail closed for authentication and require complete email providers

## Context and Problem Statement

Providers are chosen by environment variables, with `blank` adapters for vendors that are not configured.
That fallback also hid real failures.
A configured authentication provider that failed to load was replaced by `blank`, whose proxy let every request through.
Under `blank`, the `(protected)` layout hid page content, but the page still rendered into the RSC payload and its Server Actions still ran for anonymous callers.
Email providers were merged over `blank`, so a vendor missing a method silently inherited a no-op, which lost Better Auth sign-in emails when only Mailgun was configured.

How should the adapters behave when a provider is broken or only partly able to do what the port asks?

## Considered Options

- Authentication load failure: surface the error, or log it and fall back to `blank`.
- Protected routes under `blank`: redirect them to the login page in the proxy, or rely on the layout.
- Vendors missing an email type: implement the missing method, or throw when that type is requested.
- Mailgun sender: `MAILGUN_EMAIL_FROM` with a `postmaster@` default, or keep the hardcoded "Mailgun Sandbox" name.
- Better Auth sign-in with no working email: fail in the login form, fail when the adapter loads, or let the code vanish.

## Decision Outcome

Chosen options:

- Surface the error when `BETTER_AUTH_SECRET` or `AUTH_SECRET` is set and the provider fails to load, because a deployment that asked for authentication must not serve protected routes without it.
- Redirect protected routes to the login page in the `blank` proxy, because the proxy is the only layer that stops the page rendering and its Server Actions running.
- Implement the missing methods and select exactly one email provider, because both vendors can send both types and the architecture requires implementations of a port to be interchangeable.
- Use `email.from`, then `MAILGUN_EMAIL_FROM`, then `postmaster@<MAILGUN_DOMAIN>`, because the "Mailgun Sandbox" name came from Mailgun's quickstart sample and would label production mail as a sandbox.
- Fail sign-in in the login form, because a code nobody receives leaves the user stuck on a screen claiming it was sent, while failing at load would take the whole site down over a problem only sign-in has.
  The form calls `createVerificationOTP` and sends the email itself, because `sendVerificationOTP` catches send errors, logs them and reports success.

Resend takes precedence when both vendors are configured, as [ADR 0008](./0008-send-emails-with-resend-and-react-email.md) describes.

### Consequences

- Good, because a broken authentication setup is an outage rather than an open site.
- Good, because the compiler now rejects an email vendor that does not implement the whole port.
- Good, because Better Auth sign-in emails work with either vendor.
- Bad, because a broken authentication setup now takes down every route, including public ones.
- Bad, because deployments with both vendors configured now send plain emails through Resend instead of Mailgun.
- Good, because a sign-in email that cannot be sent now shows an error to the user and logs the cause.
- Bad, because the public `/api/auth/email-otp/send-verification-otp` endpoint still reports success when the send fails, and only logs the error, since that behaviour belongs to Better Auth.
