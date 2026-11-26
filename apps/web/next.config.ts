import path from 'node:path';
import type { NextConfig } from 'next';
import * as contentManagement from '@ship-it/adapters/content-management/wrappers';
import * as devTools from '@ship-it/adapters/dev-tools/wrappers';
import { wrapConfig } from '@/lib/wrap-config';
// Validates the environment when the app builds or starts, rather than on first use.
import '@/config/env';

const nextConfig: NextConfig = {
  turbopack: {
    root: path.join(__dirname, '../..'),
  },

  pageExtensions: ['js', 'jsx', 'md', 'mdx', 'ts', 'tsx'],
  transpilePackages: ['@ship-it/adapters'],
  experimental: {
    authInterrupts: true,
    serverActions: {
      bodySizeLimit: '50mb',
    },
    useTypeScriptCli: true,
  },
};

const wrappers = [
  ...devTools.wrappers,
  ...contentManagement.wrappers,
  // Add more wrappers here, as desired
];

export default wrapConfig(nextConfig, wrappers);
