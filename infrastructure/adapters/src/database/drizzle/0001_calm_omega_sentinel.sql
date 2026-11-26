ALTER TABLE "default"."sessions" ADD COLUMN "impersonated_by" text;--> statement-breakpoint
ALTER TABLE "default"."users" ADD COLUMN "blocked" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "default"."users" ADD COLUMN "block_reason" text;--> statement-breakpoint
ALTER TABLE "default"."users" ADD COLUMN "block_expires_at" timestamp;