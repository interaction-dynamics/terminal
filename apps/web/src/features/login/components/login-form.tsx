'use client';

import { useCallback, useState } from 'react';
import { useRouter } from 'next/navigation';
import { CheckCircle2, Loader2 } from 'lucide-react';
import { InputOTP, InputOTPGroup, InputOTPSlot } from '@/components/ui/input-otp';

type ActionResult = { error?: { message?: string } | string | null } | void | null | undefined;

function errorMessage(result: ActionResult, fallback: string): string | null {
  if (!result || !result.error) return null;
  const { error } = result;
  if (typeof error === 'string') return error || fallback;
  return error.message ?? fallback;
}

export interface BaseLoginFormProps {
  redirectTo?: string;
  /** `otp`: email then a verification code. `magic-link`: email then check inbox. */
  variant: 'otp' | 'magic-link';
  /** Send the code / magic link to the given email. */
  onSend: (email: string) => Promise<ActionResult>;
  /** Verify the entered code. Required for the `otp` variant. */
  onVerify?: (email: string, code: string) => Promise<ActionResult>;
  sendLabel?: string;
}

const inputClassName =
  'w-full rounded-md border border-neutral-200 bg-white px-3 py-2 text-sm placeholder:text-neutral-400 focus:outline-none focus:ring-2 focus:ring-neutral-900 dark:border-neutral-800 dark:bg-neutral-950 dark:placeholder:text-neutral-500 dark:focus:ring-neutral-300';

export function BaseLoginForm({
  redirectTo = '/dashboard',
  variant,
  onSend,
  onVerify,
  sendLabel,
}: BaseLoginFormProps) {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [otp, setOtp] = useState('');
  const [step, setStep] = useState<'email' | 'otp' | 'sent'>('email');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);

  const handleSend = async (e: React.SubmitEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const message = errorMessage(
        await onSend(email),
        variant === 'otp' ? 'Failed to send verification code' : 'Failed to send magic link',
      );
      if (message) {
        setError(message);
      } else {
        setStep(variant === 'otp' ? 'otp' : 'sent');
      }
    } catch {
      setError(
        variant === 'otp' ? 'Failed to send verification code' : 'Failed to send magic link',
      );
    } finally {
      setLoading(false);
    }
  };

  const handleVerify = useCallback(
    async (code: string) => {
      if (!onVerify) return;
      setError('');
      setLoading(true);
      try {
        const message = errorMessage(await onVerify(email, code), 'Invalid verification code');
        if (message) {
          setError(message);
          setOtp('');
        } else {
          setSuccess(true);
          router.push(redirectTo);
        }
      } catch {
        setError('Failed to verify code');
        setOtp('');
      } finally {
        setLoading(false);
      }
    },
    [email, onVerify, redirectTo, router],
  );

  // Magic-link sent confirmation.
  if (step === 'sent') {
    return (
      <div className="flex flex-col items-center justify-center gap-3 py-8 text-center">
        <CheckCircle2 className="h-12 w-12 text-green-500" />
        <p className="text-sm text-muted-foreground">
          We sent a magic link to <strong>{email}</strong>. Check your inbox to sign in.
        </p>
      </div>
    );
  }

  if (step === 'otp') {
    if (success) {
      return (
        <div className="flex flex-col items-center justify-center gap-3 py-8">
          <CheckCircle2 className="h-12 w-12 text-green-500" />
        </div>
      );
    }

    if (loading) {
      return (
        <div className="flex flex-col items-center justify-center gap-3 py-8">
          <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
          <p className="text-sm text-muted-foreground">Verifying...</p>
        </div>
      );
    }

    return (
      <div className="flex flex-col gap-4">
        <p className="text-sm text-muted-foreground">
          We sent a code to <strong>{email}</strong>
        </p>
        <div className="flex justify-center">
          <InputOTP
            maxLength={6}
            value={otp}
            onChange={setOtp}
            onComplete={handleVerify}
            disabled={loading}
            // The code field only appears after the user submits their email; moving focus
            // to it is deliberate focus management, not an unexpected jump on page load.
            // oxlint-disable-next-line jsx-a11y/no-autofocus
            autoFocus
          >
            <InputOTPGroup>
              <InputOTPSlot index={0} />
              <InputOTPSlot index={1} />
              <InputOTPSlot index={2} />
              <InputOTPSlot index={3} />
              <InputOTPSlot index={4} />
              <InputOTPSlot index={5} />
            </InputOTPGroup>
          </InputOTP>
        </div>
        {error && <p className="text-sm text-center text-red-500">{error}</p>}
        <button
          type="button"
          onClick={() => {
            setStep('email');
            setOtp('');
            setError('');
          }}
          className="text-sm text-muted-foreground hover:underline"
        >
          Use a different email
        </button>
      </div>
    );
  }

  return (
    <form onSubmit={(e) => void handleSend(e)} className="flex flex-col gap-4">
      <input
        name="email"
        type="email"
        placeholder="name@example.com"
        required
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        className={inputClassName}
      />
      {error && <p className="text-sm text-red-500">{error}</p>}
      <button
        type="submit"
        disabled={loading}
        className="inline-flex h-10 w-full items-center justify-center rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground shadow hover:bg-primary/90 disabled:opacity-50"
      >
        {loading
          ? 'Sending...'
          : (sendLabel ?? (variant === 'otp' ? 'Send verification code' : 'Send magic link'))}
      </button>
    </form>
  );
}
