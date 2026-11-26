import { neon } from '@neondatabase/serverless';
import { drizzle } from 'drizzle-orm/neon-http';
import * as schema from './schema';
import { databaseEnv } from '../env';

const { DATABASE_URL } = databaseEnv();
if (!DATABASE_URL) {
  throw new Error('DATABASE_URL is required to use the database.');
}

const sql = neon(DATABASE_URL);

export const db = drizzle(sql, { schema });
