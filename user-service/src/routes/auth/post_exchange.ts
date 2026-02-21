import { and, eq } from "drizzle-orm";
import type { Context } from "hono";
import { verifyPgsAuthCode } from "../../auth/pgs.js";
import { issueSession } from "../../auth/tokens.js";
import { config } from "../../config.js";
import { db } from "../../db/client.js";
import { accounts, authIdentities, sessions } from "../../db/schema.js";
import type { AuthExchangeResponse } from "../../types.js";
import { ulid } from "ulid";

export type ExchangeBody = {
  provider: "dev" | "pgs";
  proof: string;
};

type ResolvedProviderIdentity =
  | {
      success: true;
      providerSubject: string;
      providerUsername: string;
    }
  | {
      success: false;
      statusCode: 401 | 503;
      error: "INVALID_PROVIDER_PROOF" | "PGS_PROVIDER_UNAVAILABLE";
    };

function resolveDevIdentity(proof: string): ResolvedProviderIdentity {
  return {
    success: true,
    providerSubject: proof.split(":")[0] ?? proof,
    providerUsername: "DEV_PLAYER"
  };
}

async function resolvePgsIdentity(proof: string): Promise<ResolvedProviderIdentity> {
  const verification = await verifyPgsAuthCode({
    serverAuthCode: proof,
    webClientId: config.pgsWebClientId,
    webClientSecret: config.pgsWebClientSecret
  });
  if (!verification.success) {
    return {
      success: false,
      statusCode: verification.reason === "PGS_PROVIDER_UNAVAILABLE" ? 503 : 401,
      error: verification.reason
    };
  }
  return {
    success: true,
    providerSubject: verification.providerSubject,
    providerUsername: verification.displayName
  };
}

export async function postExchangeHandler(context: Context) {
  const body = await context.req.json<ExchangeBody>();
  if (config.stage === "prod" && body.provider === "dev") {
    return context.json({ error: "PROVIDER_NOT_ALLOWED" }, 403);
  }

  const identity =
    body.provider === "dev" ? resolveDevIdentity(body.proof) : await resolvePgsIdentity(body.proof);
  if (!identity.success) {
    return context.json({ error: identity.error }, identity.statusCode);
  }

  const issuedSession = issueSession(config.sessionTtlSeconds);

  const result = await db.transaction(async (tx) => {
    const existingIdentity = await tx.query.authIdentities.findFirst({
      columns: { account_id: true },
      where: and(
        eq(authIdentities.provider, body.provider),
        eq(authIdentities.provider_subject, identity.providerSubject)
      )
    });

    let accountId = existingIdentity?.account_id ?? "";
    let isNewAccount = false;

    if (!accountId) {
      isNewAccount = true;
      const createdAccountId = ulid();
      accountId = createdAccountId;
      await tx.insert(accounts).values({
        account_id: createdAccountId,
        username: identity.providerUsername.trim()
      });
      await tx.insert(authIdentities).values({
        provider: body.provider,
        provider_subject: identity.providerSubject,
        account_id: createdAccountId
      });
    }

    await tx.delete(sessions).where(eq(sessions.account_id, accountId));

    await tx.insert(sessions).values({
      account_id: accountId,
      session_token_hash: issuedSession.tokenHash,
      expires_at_unix: issuedSession.expiresAtUnix
    });
    return {
      isNewAccount,
      accountId
    };
  });

  return context.json<AuthExchangeResponse>({
    account_id: result.accountId,
    session_token: issuedSession.token,
    expires_at_unix: issuedSession.expiresAtUnix,
    is_new_account: result.isNewAccount
  });
}
