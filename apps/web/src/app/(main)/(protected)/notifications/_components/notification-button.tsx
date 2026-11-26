'use client';
import { CheckCircle, Loader2, XCircle } from 'lucide-react';
import { useTransition, useState } from 'react';
import { Button } from '@/components/ui/button';
import { sendTestNotification } from '../_use-cases/send-test-notification';

export function NotificationButton() {
  const [isPending, startTransition] = useTransition();
  const [result, setResult] = useState<{ success: boolean; error?: string } | null>(null);

  function handleClick() {
    setResult(null);
    startTransition(async () => {
      const res = await sendTestNotification();
      setResult(res);
    });
  }

  return (
    <div className="flex items-center gap-3">
      <Button onClick={handleClick} disabled={isPending}>
        {isPending && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
        Send Notification
      </Button>

      {result?.success && (
        <span className="flex items-center gap-1 text-sm text-green-600">
          <CheckCircle className="h-4 w-4" />
          Notification sent
        </span>
      )}

      {result && !result.success && (
        <span className="flex items-center gap-1 text-sm text-destructive">
          <XCircle className="h-4 w-4" />
          {result.error ?? 'Failed to send notification'}
        </span>
      )}
    </div>
  );
}
