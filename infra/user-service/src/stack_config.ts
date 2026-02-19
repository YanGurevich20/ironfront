import * as pulumi from "@pulumi/pulumi";

const gcpCfg = new pulumi.Config("gcp");
const stackCfg = new pulumi.Config();

export const project = gcpCfg.require("project");
export const region = gcpCfg.require("region");

export const serviceName = stackCfg.require("serviceName");
export const artifactRepoId = stackCfg.require("artifactRepoId");
export const imageTag = stackCfg.require("imageTag");
export const stage = stackCfg.require("stage");
export const allowUnauthenticated = stackCfg.requireBoolean("allowUnauthenticated");
export const minInstanceCount = stackCfg.requireNumber("minInstanceCount");
export const maxInstanceCount = stackCfg.requireNumber("maxInstanceCount");
export const enableCustomDomain = stackCfg.requireBoolean("enableCustomDomain");
export const customDomain = stackCfg.require("customDomain");
export const sessionTtlSeconds = stackCfg.requireNumber("sessionTtlSeconds");
export const dbInstanceName = stackCfg.require("dbInstanceName");
export const dbName = stackCfg.require("dbName");
export const dbUserName = stackCfg.require("dbUserName");
export const dbUserPassword = stackCfg.requireSecret("dbUserPassword");
export const dbTier = stackCfg.require("dbTier");
export const dbEdition = stackCfg.require("dbEdition");
export const dbDeletionProtection = stackCfg.requireBoolean("dbDeletionProtection");
export const cloudRunDeletionProtection = stackCfg.getBoolean("cloudRunDeletionProtection") ?? true;
export const dbSecretName = stackCfg.require("dbSecretName");
export const dbVersion = stackCfg.require("dbVersion");
export const pgsWebClientId = stackCfg.get("pgsWebClientId") ?? "";
export const pgsWebClientSecret = stackCfg.getSecret("pgsWebClientSecret");
export const pgsWebClientSecretName = stackCfg.get("pgsWebClientSecretName") ?? "";

if (stage === "prod") {
  if (!pgsWebClientId) {
    throw new Error("user-service-infra:pgsWebClientId is required for prod");
  }
  if (!pgsWebClientSecretName) {
    throw new Error("user-service-infra:pgsWebClientSecretName is required for prod");
  }
  if (!pgsWebClientSecret) {
    throw new Error("user-service-infra:pgsWebClientSecret is required for prod");
  }
}
