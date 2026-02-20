import { eq } from "drizzle-orm";
import type { Context } from "hono";
import { db } from "../../db/client.js";
import { accounts } from "../../db/schema.js";
import type { MeRouteVars } from "./require_bearer_session.js";

type PatchUsernameBody = {
  username: string;
};

export async function patchUsernameHandler(context: Context<{ Variables: MeRouteVars }>) {
  const accountId = context.var.accountId;
  const body = await context.req.json<PatchUsernameBody>();

  const username = body.username.trim();
  await db
    .update(accounts)
    .set({
      username,
      username_updated_at: new Date(),
      updated_at: new Date()
    })
    .where(eq(accounts.account_id, accountId));

  const account = await db.query.accounts.findFirst({
    where: eq(accounts.account_id, accountId)
  });
  if (!account) {
    return context.json({ error: "PROFILE_NOT_FOUND" }, 404);
  }

  return context.json({
    account_id: account.account_id,
    username: account.username,
    username_updated_at: account.username_updated_at
  });
}
