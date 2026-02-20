import { zValidator } from "@hono/zod-validator";
import { Hono } from "hono";
import { z } from "zod";
import { getMeHandler } from "./get_me.js";
import { patchUsernameHandler } from "./patch_username.js";
import { requireBearerSession, type MeRouteVars } from "./require_bearer_session.js";

export const meRouter = new Hono<{ Variables: MeRouteVars }>();

meRouter.get("/", requireBearerSession, getMeHandler);
meRouter.patch(
  "/username",
  requireBearerSession,
  zValidator(
    "json",
    z.object({
      username: z.string().trim().min(1).max(32)
    }),
    (result, context) => {
      if (!result.success) {
        return context.json(
          { error: "INVALID_REQUEST", details: z.flattenError(result.error) },
          400
        );
      }
    }
  ),
  patchUsernameHandler
);
