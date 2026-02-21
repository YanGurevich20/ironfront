import { eq } from "drizzle-orm";
import type { Context } from "hono";
import { verifyPgsAuthCode } from "../../auth/pgs.js";
import { issueSession } from "../../auth/tokens.js";
import { config } from "../../config.js";
import { db } from "../../db/client.js";
import { getOrCreateAccount } from "../../db/queries/get_or_create_account.js";
import { sessions } from "../../db/schema.js";
import type { AuthExchangeResponse } from "../../types.js";

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
    const accountResult = await getOrCreateAccount(tx, {
      provider: body.provider,
      providerSubject: identity.providerSubject,
      providerUsername: identity.providerUsername
    });
    const accountId = accountResult.accountId;

    await tx
      .insert(sessions)
      .values({
        account_id: accountId,
        session_token_hash: issuedSession.tokenHash,
        expires_at_unix: issuedSession.expiresAtUnix
      })
      .onConflictDoUpdate({
        target: sessions.account_id,
        set: {
          session_token_hash: issuedSession.tokenHash,
          expires_at_unix: issuedSession.expiresAtUnix
        }
      });
    return {
      isNewAccount: accountResult.isNewAccount,
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
