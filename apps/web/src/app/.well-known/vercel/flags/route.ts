import { createFlagsDiscoveryEndpoint, getProviderData } from 'flags/next';
// Relative on purpose: tsconfig `include` globs skip dot-directories such as `.well-known`, so the
// `@/` path alias is not applied to this file and type-aware lint would see an unresolved module.
import * as flags from '../../../../config/flags';

export const GET = createFlagsDiscoveryEndpoint(() => getProviderData(flags));
