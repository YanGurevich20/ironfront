import { createArtifactRepo } from "./artifact.ts";
import { createCiServiceAccount } from "./ci_identity.ts";
import { applyCloudBuildIam } from "./cloudbuild.ts";
import { createNetwork } from "./network.ts";
import { enableProjectServices } from "./services.ts";
import {
  artifactRepoId,
  artifactRepoPullProjectNumber,
  artifactRepoRuntimeServiceAccounts,
  ciServiceAccountId,
  cloudBuildSourceBucket,
  project,
  region,
  subnetCidr,
  subnetName,
  vpcName
} from "./stack_config.ts";

const enabledServices = enableProjectServices(project);
const { serviceAccount: ciServiceAccount } = createCiServiceAccount({
  project,
  ciServiceAccountId,
  dependsOn: enabledServices
});

const { network, subnet } = createNetwork({
  project,
  region,
  vpcName,
  subnetName,
  subnetCidr,
  dependsOn: enabledServices
});

const { artifactRepo } = createArtifactRepo({
  project,
  region,
  artifactRepoId,
  artifactRepoPullProjectNumber,
  artifactRepoRuntimeServiceAccounts,
  artifactRepoWriterServiceAccounts: [ciServiceAccount.email],
  dependsOn: enabledServices
});

applyCloudBuildIam({
  project,
  cloudBuildSourceBucket,
  cloudBuildBucketObjectAdminServiceAccounts: [ciServiceAccount.email],
  cloudBuildLogWriterServiceAccounts: [ciServiceAccount.email]
});

export const gcpProject = project;
export const gcpRegion = region;
export const vpcId = network.id;
export const subnetworkId = subnet.id;
export const artifactRegistryRepository = artifactRepo.id;
export const ciServiceAccountEmail = ciServiceAccount.email;
