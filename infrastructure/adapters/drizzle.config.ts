import { config } from 'dotenv';
import { defineConfig } from 'drizzle-kit';
import { schemaName } from './src/database/drizzle/schema/table';

config({ path: '../../apps/web/.env.local' });

export default defineConfig({
  schema: './src/database/drizzle/schema/index.ts',
  out: './src/database/drizzle',
  dialect: 'postgresql',
  schemaFilter: [schemaName],
  dbCredentials: {
    url: process.env.DATABASE_URL ?? '',
  },
});
