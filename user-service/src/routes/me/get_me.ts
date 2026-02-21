import { eq } from "drizzle-orm";
import type { Context } from "hono";
import { db } from "../../db/client.js";
import { accounts } from "../../db/schema.js";
import type { MeRouteVars } from "./require_bearer_session.js";

type MeResponse = {
  account_id: string;
  username: string | null;
  username_updated_at_unix: number | null;
  economy: typeof accounts.$inferSelect.economy;
  loadout: typeof accounts.$inferSelect.loadout;
};

export async function getMeHandler(context: Context<{ Variables: MeRouteVars }>) {
  const accountId = context.var.accountId;
  const account = await db.query.accounts.findFirst({
    where: eq(accounts.account_id, accountId),
    columns: {
      account_id: true,
      username: true,
      username_updated_at_unix: true,
      economy: true,
      loadout: true,
    }
  });
  if (!account) {
    return context.json({ error: "PROFILE_NOT_FOUND" }, 404);
  }
  return context.json<MeResponse>(account);
}
