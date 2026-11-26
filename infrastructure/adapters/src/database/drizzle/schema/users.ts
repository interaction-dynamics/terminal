import { boolean, text, timestamp } from 'drizzle-orm/pg-core';
import { schema } from './table';

export const users = schema.table('users', {
  id: text('id').primaryKey(),
  email: text('email').notNull().unique(),
  emailVerified: boolean('email_verified').notNull().default(false),
  name: text('name').notNull(),
  image: text('image'),
  role: text('role').notNull().default('user'),
  blocked: boolean('blocked').notNull().default(false),
  blockReason: text('block_reason'),
  blockExpiresAt: timestamp('block_expires_at'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
});
