import * as pulumi from "@pulumi/pulumi";

const gcpCfg = new pulumi.Config("gcp");
const stackCfg = new pulumi.Config();

export const project = gcpCfg.require("project");
export const region = gcpCfg.require("region");

export const artifactRepoId = stackCfg.require("artifactRepoId");
export const vpcName = stackCfg.require("vpcName");
export const subnetName = stackCfg.require("subnetName");
export const subnetCidr = stackCfg.require("subnetCidr");
export const artifactRepoPullProjectNumber = stackCfg.require("artifactRepoPullProjectNumber");
export const artifactRepoRuntimeServiceAccounts = stackCfg.requireObject<string[]>(
  "artifactRepoRuntimeServiceAccounts"
);
export const ciServiceAccountId = stackCfg.require("ciServiceAccountId");
export const cloudBuildSourceBucket = stackCfg.require("cloudBuildSourceBucket");
