import type { Instrumentation } from 'next';
import type { NextFetchEvent, NextRequest } from 'next/server';

export function logError(message: string, error: unknown): void {
  console.error(message, error);
}

export function WebVitals(): null {
  return null;
}

export const onRequestError: Instrumentation.onRequestError = () => {};

export function logRequest(_request: NextRequest, _event: NextFetchEvent): void {}
