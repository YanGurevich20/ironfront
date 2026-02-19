import { and, eq } from "drizzle-orm";
import type { Context } from "hono";
import crypto from "node:crypto";
import { issueSession } from "../../auth/tokens.js";
import { config } from "../../config.js";
import { db } from "../../db/client.js";
import { accounts, authIdentities, sessions } from "../../db/schema.js";
import type { AuthExchangeResponse } from "../../types.js";

export type ExchangeBody = {
  provider: "dev" | "pgs";
  proof: string;
  client: {
    stage: "dev" | "prod";
    app_version?: string;
    platform?: string;
  };
};

function newAccountId(): string {
  return `acc_${crypto.randomBytes(5).toString("hex")}`;
}

function isAuthIdentityUniqueViolation(error: unknown): boolean {
  if (!error || typeof error !== "object") {
    return false;
  }
  const candidate = error as { code?: string; constraint?: string };
  return candidate.code === "23505" && candidate.constraint === "auth_identities_provider_subject_idx";
}

export async function postExchangeHandler(context: Context) {
  const body = await context.req.json<ExchangeBody>();
  if (config.stage === "prod" && body.provider === "dev") {
    return context.json({ error: "PROVIDER_NOT_ALLOWED" }, 403);
  }

  const providerSubject = body.provider === "dev" ? body.proof.split(":")[0] ?? body.proof : body.proof;
  const issuedSession = issueSession(config.sessionTtlSeconds);

  const result = await db.transaction(async (tx) => {
      const existingIdentity = await tx.query.authIdentities.findFirst({
      columns: { account_id: true },
      where: and(
        eq(authIdentities.provider, body.provider),
        eq(authIdentities.provider_subject, providerSubject)
      )
    });

    let accountId = existingIdentity?.account_id ?? "";
    let isNewAccount = false;

    if (!accountId) {
      isNewAccount = true;
      const createdAccountId = newAccountId();
      accountId = createdAccountId;
      await tx.insert(accounts).values({
        account_id: createdAccountId,
        display_name: body.provider === "dev" ? "DEV_PLAYER" : ""
      });
      try {
        await tx.insert(authIdentities).values({
          provider: body.provider,
          provider_subject: providerSubject,
          account_id: createdAccountId
        });
      } catch (error) {
        if (!isAuthIdentityUniqueViolation(error)) {
          throw error;
        }
        isNewAccount = false;
        const takenIdentity = await tx.query.authIdentities.findFirst({
          columns: { account_id: true },
          where: and(
            eq(authIdentities.provider, body.provider),
            eq(authIdentities.provider_subject, providerSubject)
          )
        });
        if (!takenIdentity) {
          throw new Error("AUTH_IDENTITY_RESOLVE_FAILED");
        }
        accountId = takenIdentity.account_id;
        await tx.delete(accounts).where(eq(accounts.account_id, createdAccountId));
      }
    }

    await tx.insert(sessions).values({
      account_id: accountId,
      session_token_hash: issuedSession.tokenHash,
      expires_at_unix: issuedSession.expiresAtUnix
    });

    const account = await tx.query.accounts.findFirst({
      where: eq(accounts.account_id, accountId)
    });
    if (!account) {
      throw new Error("ACCOUNT_NOT_FOUND");
    }
    return {
      isNewAccount,
      profile: {
        account_id: account.account_id,
        username: account.username,
        display_name: account.display_name
      }
    };
  });

  const response: AuthExchangeResponse = {
    account_id: result.profile.account_id,
    session_token: issuedSession.token,
    expires_at_unix: issuedSession.expiresAtUnix,
    is_new_account: result.isNewAccount,
    profile: {
      username: result.profile.username,
      display_name: result.profile.display_name
    }
  };

  return context.json(response);
}
