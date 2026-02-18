import { Router } from "express";
import { z } from "zod";
import { config } from "../config.js";
import { issueSession } from "../auth/tokens.js";
import type { AuthExchangeResponse, Profile } from "../types.js";

const requestSchema = z.object({
  provider: z.enum(["dev", "pgs"]),
  proof: z.string().min(1),
  client: z.object({
    stage: z.enum(["dev", "prod"]),
    app_version: z.string().optional(),
    platform: z.string().optional()
  })
});

const profileByAccountId = new Map<string, Profile>();
const accountByProviderKey = new Map<string, string>();

function getOrCreateProfile(provider: "dev" | "pgs", proof: string): { profile: Profile; isNewAccount: boolean } {
  const providerIdentity = provider === "dev" ? proof.split(":")[0] ?? proof : proof;
  const providerKey = `${provider}:${providerIdentity}`;
  const existingAccountId = accountByProviderKey.get(providerKey);
  if (existingAccountId) {
    const existingProfile = profileByAccountId.get(existingAccountId);
    if (!existingProfile) {
      throw new Error("DATA_INTEGRITY_ERROR");
    }
    return { profile: existingProfile, isNewAccount: false };
  }

  const accountId = `acc_${Math.random().toString(36).slice(2, 12)}`;
  const profile: Profile = {
    account_id: accountId,
    username: "",
    display_name: provider === "dev" ? "DEV_PLAYER" : "",
    progression: {},
    economy: {},
    loadout: {}
  };
  accountByProviderKey.set(providerKey, accountId);
  profileByAccountId.set(accountId, profile);
  return { profile, isNewAccount: true };
}

export const authExchangeRouter = Router();

authExchangeRouter.post("/auth/exchange", (req, res) => {
  const parsed = requestSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "INVALID_REQUEST", details: parsed.error.flatten() });
    return;
  }

  const body = parsed.data;
  if (config.stage === "prod" && body.provider === "dev") {
    res.status(403).json({ error: "PROVIDER_NOT_ALLOWED" });
    return;
  }

  const { profile, isNewAccount } = getOrCreateProfile(body.provider, body.proof);
  const session = issueSession(profile.account_id, config.sessionTtlSeconds);

  const response: AuthExchangeResponse = {
    account_id: profile.account_id,
    session_token: session.token,
    expires_at_unix: session.expiresAtUnix,
    is_new_account: isNewAccount,
    profile: {
      username: profile.username,
      display_name: profile.display_name
    }
  };

  res.status(200).json(response);
});

export function loadProfileByAccountId(accountId: string): Profile | null {
  return profileByAccountId.get(accountId) ?? null;
}
