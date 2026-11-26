import type React from 'react';

export type ActionResult = { error?: string | null } | void | null | undefined;

export interface LoginFormComponentProps {
  redirectTo?: string;
  variant: 'otp' | 'magic-link';
  onSend: (email: string) => Promise<ActionResult>;
  onVerify?: (email: string, code: string) => Promise<ActionResult>;
  sendLabel?: string;
}

export interface AuthAdapterConfig {
  protectedRoutes: string[];
  LoginFormComponent?: React.ComponentType<LoginFormComponentProps>;
}
