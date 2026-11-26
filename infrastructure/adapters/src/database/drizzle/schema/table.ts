import { pgSchema } from 'drizzle-orm/pg-core';

/**
 * Shared Postgres schema for all tables so the namespace stays centralized.
 * Define tables with `schema.table(...)` instead of `pgTable(...)`.
 */
export const schemaName = 'default';

export const schema = pgSchema(schemaName);
