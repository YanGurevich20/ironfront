import { eq } from "drizzle-orm";
import type { Context } from "hono";
import { db } from "../../db/client.js";
import { accounts } from "../../db/schema.js";
import type { MeRouteVars } from "./require_bearer_session.js";

export async function getMeHandler(context: Context<{ Variables: MeRouteVars }>) {
  const accountId = context.var.accountId;
  const account = await db.query.accounts.findFirst({
    where: eq(accounts.account_id, accountId)
  });
  if (!account) {
    return context.json({ error: "PROFILE_NOT_FOUND" }, 404);
  }
  return context.json({
    account_id: account.account_id,
    username: account.username,
    display_name: account.display_name,
    progression: account.progression,
    economy: account.economy,
    loadout: account.loadout
  });
}
