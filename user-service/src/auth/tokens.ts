import crypto from "node:crypto";

export function issueSession(ttlSeconds: number): { token: string; tokenHash: string; expiresAtUnix: number } {
  const nowUnix = Math.floor(Date.now() / 1000);
  const expiresAtUnix = nowUnix + ttlSeconds;
  const token = crypto.randomBytes(32).toString("hex");
  const tokenHash = hashToken(token);
  return { token, tokenHash, expiresAtUnix };
}

export function hashToken(token: string): string {
  return crypto.createHash("sha256").update(token).digest("hex");
}
