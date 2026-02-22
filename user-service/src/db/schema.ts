import { integer, jsonb, pgTable, text, timestamp, uniqueIndex } from "drizzle-orm/pg-core";
import { ulid } from "ulid";

type AccountTankLoadout = {
  unlocked_shell_ids: string[];
  shell_loadout_by_id: Record<string, number>;
};

type AccountEconomy = {
  dollars: number;
  bonds: number;
};

export type AccountLoadout = {
  selected_tank_id: string | null;
  tanks: Record<string, AccountTankLoadout>;
};

export const accounts = pgTable("accounts", {
  account_id: text().$defaultFn(() => ulid()).primaryKey(),
  username: text(),
  username_updated_at_unix: integer(),
  economy: jsonb().notNull().$type<AccountEconomy>().default({dollars: 1_000, bonds: 0}),
  loadout: jsonb()
    .notNull()
    .$type<AccountLoadout>()
    .default({selected_tank_id: null, tanks: {}}),
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

export const sessions = pgTable(
  "sessions",
  {
    session_token_hash: text().primaryKey(),
    account_id: text()
      .notNull()
      .references(() => accounts.account_id, { onDelete: "cascade" }),
    expires_at_unix: integer().notNull(),
    created_at: timestamp({ withTimezone: true }).notNull().defaultNow()
  },
  (table) => [uniqueIndex("sessions_account_id_idx").on(table.account_id)]
);
