import { and, eq, gt } from "drizzle-orm";
import { createMiddleware } from "hono/factory";
import { hashToken } from "../../auth/tokens.js";
import { db } from "../../db/client.js";
import { sessions } from "../../db/schema.js";

export type MeRouteVars = {
  accountId: string;
};

export const requireBearerSession = createMiddleware<{ Variables: MeRouteVars }>(
  async (context, next) => {
  const header = context.req.header("authorization") ?? "";
  const [scheme, token] = header.split(" ");
  if (scheme !== "Bearer" || !token) {
    return context.json({ error: "UNAUTHORIZED" }, 401);
  }

  const session = await db.query.sessions.findFirst({
    columns: { account_id: true },
    where: and(
      eq(sessions.session_token_hash, hashToken(token)),
      gt(sessions.expires_at_unix, Math.floor(Date.now() / 1000))
    )
  });
  if (!session) {
    return context.json({ error: "UNAUTHORIZED" }, 401);
  }

  context.set("accountId", session.account_id);
  await next();
  }
);
