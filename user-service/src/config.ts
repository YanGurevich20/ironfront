import type { Stage } from "./types.js";

const stageValue = process.env.STAGE;
if (stageValue !== "dev" && stageValue !== "prod") {
  throw new Error(`Invalid STAGE: ${stageValue}`);
}
const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) {
  throw new Error("DATABASE_URL is required");
}

export const config = {
  port: Number(process.env.PORT ?? 8080),
  stage: stageValue as Stage,
  sessionTtlSeconds: Number(process.env.SESSION_TTL_SECONDS ?? 86_400),
  databaseUrl
};
