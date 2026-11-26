/**
 * Why an admin operation on users was refused:
 * - `forbidden`: the caller is not a signed-in admin.
 * - `self`: admins cannot remove, block or change the role of their own account, so the
 *   application cannot lose its last admin by accident.
 * - `not-found`: no user has that id.
 * - `unavailable`: no authentication provider is configured.
 */
export type UserAdministrationErrorCode = 'forbidden' | 'self' | 'not-found' | 'unavailable';

export class UserAdministrationError extends Error {
  readonly code: UserAdministrationErrorCode;

  constructor(code: UserAdministrationErrorCode, options?: { cause?: unknown }) {
    super(`User administration refused: ${code}`, options);
    this.name = 'UserAdministrationError';
    this.code = code;
  }
}

/**
 * Whether `error` is a `UserAdministrationError`. Checks its shape rather than `instanceof`, which
 * fails when the error comes from another copy of this module (a separate bundle, or a test that
 * reloads modules).
 */
export function isUserAdministrationError(error: unknown): error is UserAdministrationError {
  return (
    error instanceof Error &&
    error.name === 'UserAdministrationError' &&
    typeof (error as Partial<UserAdministrationError>).code === 'string'
  );
}
