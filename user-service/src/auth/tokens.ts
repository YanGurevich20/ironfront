import crypto from "node:crypto";

type SessionRecord = {
  accountId: string;
  expiresAtUnix: number;
};

const sessionByToken = new Map<string, SessionRecord>();

export function issueSession(accountId: string, ttlSeconds: number): { token: string; expiresAtUnix: number } {
  const now = Math.floor(Date.now() / 1000);
  const expiresAtUnix = now + ttlSeconds;
  const token = crypto.randomBytes(32).toString("hex");
  sessionByToken.set(token, { accountId, expiresAtUnix });
  return { token, expiresAtUnix };
}

export function resolveSession(token: string): SessionRecord | null {
  const record = sessionByToken.get(token);
  if (!record) {
    return null;
  }
  const now = Math.floor(Date.now() / 1000);
  if (record.expiresAtUnix <= now) {
    sessionByToken.delete(token);
    return null;
  }
  return record;
}
