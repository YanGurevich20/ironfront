import { execFileSync } from "child_process";
import fs from "fs";
import path from "path";

type PulumiConfigEntry = {
  value?: string;
  secret: boolean;
};

type PulumiConfig = Record<string, PulumiConfigEntry>;

function parseEnvFile(filePath: string): Record<string, string> {
  if (!fs.existsSync(filePath)) {
    return {};
  }
  const out: Record<string, string> = {};
  const raw = fs.readFileSync(filePath, "utf8");
  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) {
      continue;
    }
    const match = trimmed.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
    if (!match || match[1] === undefined) {
      continue;
    }
    const key = match[1];
    let value = match[2] ?? "";
    if (
      (value.startsWith("'") && value.endsWith("'")) ||
      (value.startsWith('"') && value.endsWith('"'))
    ) {
      value = value.slice(1, -1);
    }
    out[key] = value;
  }
  return out;
}

function getPulumiConfig(stack: string, infraDir: string): PulumiConfig {
  const json = execFileSync("pulumi", ["config", "--json", "--stack", stack], {
    cwd: infraDir,
    encoding: "utf8"
  });
  return JSON.parse(json) as PulumiConfig;
}

function getPulumiOutput(stack: string, infraDir: string, name: string): string {
  return execFileSync("pulumi", ["stack", "output", "--stack", stack, name], {
    cwd: infraDir,
    encoding: "utf8"
  }).trim();
}

function getRequiredConfig(config: PulumiConfig, key: string): string {
  const value = config[key]?.value?.trim() ?? "";
  if (!value) {
    throw new Error(`Missing required Pulumi config: ${key}`);
  }
  return value;
}

function getMergedEnvVar(
  envFileValues: Record<string, string>,
  key: string
): string {
  return (process.env[key] ?? envFileValues[key] ?? "").trim();
}

function shellQuote(value: string): string {
  return `'${value.replace(/'/g, `'\\''`)}'`;
}

function main() {
  const stack = (process.argv[2] ?? "").trim();
  if (stack !== "prod") {
    throw new Error("Usage: tsx src/scripts/resolve_stack_env.ts prod");
  }

  const repoRoot = path.resolve(process.cwd(), "..");
  const infraDir = path.join(repoRoot, "infra/user-service");
  const envFilePath = path.join(repoRoot, `infra/.env.${stack}`);
  const envFileValues = parseEnvFile(envFilePath);
  const config = getPulumiConfig(stack, infraDir);

  const stackStage = getRequiredConfig(config, "user-service-infra:stage");
  const gcpProject = getRequiredConfig(config, "gcp:project");
  const gcpRegion = getRequiredConfig(config, "gcp:region");
  const dbInstance = getRequiredConfig(config, "user-service-infra:dbInstanceName");
  const dbName = getRequiredConfig(config, "user-service-infra:dbName");
  const dbUser = getRequiredConfig(config, "user-service-infra:dbUserName");
  const pgsWebClientId = (config["user-service-infra:pgsWebClientId"]?.value ?? "").trim();
  const customDomain = (config["user-service-infra:customDomain"]?.value ?? "").trim();

  const dbPassword = getMergedEnvVar(envFileValues, "USER_SERVICE_DB_PASSWORD");
  if (!dbPassword) {
    throw new Error(
      `Missing USER_SERVICE_DB_PASSWORD. Set it in ${envFilePath} or your current environment.`
    );
  }

  const pgsWebClientSecret =
    getMergedEnvVar(envFileValues, "PGS_WEB_CLIENT_SECRET") ||
    getMergedEnvVar(envFileValues, "USER_SERVICE_PGS_WEB_CLIENT_SECRET");
  if (!pgsWebClientId || !pgsWebClientSecret) {
    throw new Error(
      `Missing PGS credentials. Set PGS_WEB_CLIENT_SECRET or USER_SERVICE_PGS_WEB_CLIENT_SECRET in ${envFilePath} or your current environment.`
    );
  }

  const apiBaseUrl = customDomain
    ? `https://${customDomain}`
    : getPulumiOutput(stack, infraDir, "serviceUrl");

  const values: Record<string, string> = {
    STACK_NAME: stack,
    STACK_STAGE: stackStage,
    STACK_GCP_PROJECT: gcpProject,
    STACK_GCP_REGION: gcpRegion,
    STACK_DB_INSTANCE: dbInstance,
    STACK_DB_NAME: dbName,
    STACK_DB_USER: dbUser,
    STACK_DB_PASSWORD_ENCODED: encodeURIComponent(dbPassword),
    STACK_PGS_WEB_CLIENT_ID: pgsWebClientId,
    STACK_PGS_WEB_CLIENT_SECRET: pgsWebClientSecret,
    STACK_API_BASE_URL: apiBaseUrl
  };

  for (const [key, value] of Object.entries(values)) {
    console.log(`${key}=${shellQuote(value)}`);
  }
}

main();
