import { getProvider } from '@ship-it/adapters/authentication';
import type { AuthAdapterConfig } from '@ship-it/adapters/authentication';
export {
  isUserAdministrationError,
  type UserAdministrationErrorCode,
} from '@ship-it/adapters/authentication';
import { protectedRoutes } from '@/app/(main)/(protected)/protected-routes';
import { BaseLoginForm } from '@/features/login';

const provider = await getProvider({
  protectedRoutes,
  LoginFormComponent: BaseLoginForm,
} satisfies AuthAdapterConfig);

export const {
  authProxy,
  SignedIn,
  SignedOut,
  RedirectToSignIn,
  LoginForm,
  AuthenticationProvider,
  signIn,
  signOut,
  isAdmin,
  getCurrentUser,
  listUsers,
  setUserRole,
  blockUser,
  unblockUser,
  removeUser,
} = provider;
