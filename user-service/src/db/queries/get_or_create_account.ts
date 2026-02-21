import { and, eq } from "drizzle-orm";
import type { DbTransactionClient } from "../client.js";
import { accounts, authIdentities } from "../schema.js";

type GetOrCreateAccountParams = {
  provider: "dev" | "pgs";
  providerSubject: string;
  providerUsername: string;
};

export type GetOrCreateAccountResult = {
  accountId: string;
  isNewAccount: boolean;
};

export async function getOrCreateAccount(
  tx: DbTransactionClient,
  params: GetOrCreateAccountParams
): Promise<GetOrCreateAccountResult> {
  const existingIdentity = await tx.query.authIdentities.findFirst({
    columns: { account_id: true },
    where: and(
      eq(authIdentities.provider, params.provider),
      eq(authIdentities.provider_subject, params.providerSubject)
    )
  });

  const existingAccountId = existingIdentity?.account_id;
  if (existingAccountId) {
    return {
      accountId: existingAccountId,
      isNewAccount: false
    };
  }

  const [insertedAccount] = await tx
    .insert(accounts)
    .values({
      username: params.providerUsername.trim()
    })
    .returning({ account_id: accounts.account_id });
  if (!insertedAccount) {
    throw new Error("ACCOUNT_ID_GENERATION_FAILED");
  }

  await tx.insert(authIdentities).values({
    provider: params.provider,
    provider_subject: params.providerSubject,
    account_id: insertedAccount.account_id
  });

  return {
    accountId: insertedAccount.account_id,
    isNewAccount: true
  };
}
