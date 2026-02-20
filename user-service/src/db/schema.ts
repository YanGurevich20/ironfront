import { integer, jsonb, pgTable, text, timestamp, uniqueIndex } from "drizzle-orm/pg-core";

export const accounts = pgTable("accounts", {
  account_id: text().primaryKey(),
  username: text().notNull().default(""),
  username_updated_at: timestamp({ withTimezone: true }),
  progression: jsonb().notNull().$type<Record<string, unknown>>().default({}),
  economy: jsonb().notNull().$type<Record<string, unknown>>().default({}),
  loadout: jsonb().notNull().$type<Record<string, unknown>>().default({}),
  created_at: timestamp({ withTimezone: true }).notNull().defaultNow(),
  updated_at: timestamp({ withTimezone: true }).notNull().defaultNow()
});

export const authIdentities = pgTable(
  "auth_identities",
  {
    provider: text().notNull(),
    provider_subject: text().notNull(),
    account_id: text()
      .notNull()
      .references(() => accounts.account_id, { onDelete: "cascade" }),
    created_at: timestamp({ withTimezone: true }).notNull().defaultNow()
  },
  (table) => [
    uniqueIndex("auth_identities_provider_subject_idx").on(
      table.provider,
      table.provider_subject
    )
  ]
);

export const sessions = pgTable("sessions", {
  session_token_hash: text().primaryKey(),
  account_id: text()
    .notNull()
    .references(() => accounts.account_id, { onDelete: "cascade" }),
  expires_at_unix: integer().notNull(),
  created_at: timestamp({ withTimezone: true }).notNull().defaultNow()
});
