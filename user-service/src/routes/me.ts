import type { NextFunction, Request, Response } from "express";
import { Router } from "express";
import { resolveSession } from "../auth/tokens.js";
import { loadProfileByAccountId } from "./auth_exchange.js";

type AuthedRequest = Request & { accountId: string };

function requireBearerSession(req: Request, res: Response, next: NextFunction): void {
  const header = req.header("authorization") ?? "";
  const [scheme, token] = header.split(" ");
  if (scheme !== "Bearer" || !token) {
    res.status(401).json({ error: "UNAUTHORIZED" });
    return;
  }

  const session = resolveSession(token);
  if (!session) {
    res.status(401).json({ error: "UNAUTHORIZED" });
    return;
  }

  (req as AuthedRequest).accountId = session.accountId;
  next();
}

export const meRouter = Router();

meRouter.get("/me", requireBearerSession, (req, res) => {
  const authed = req as AuthedRequest;
  const profile = loadProfileByAccountId(authed.accountId);
  if (!profile) {
    res.status(404).json({ error: "PROFILE_NOT_FOUND" });
    return;
  }
  res.status(200).json(profile);
});
