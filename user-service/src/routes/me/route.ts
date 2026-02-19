import { Hono } from "hono";
import { getMeHandler } from "./get_me.js";
import { requireBearerSession, type MeRouteVars } from "./require_bearer_session.js";

export const meRouter = new Hono<{ Variables: MeRouteVars }>();

meRouter.get("/", requireBearerSession, getMeHandler);
