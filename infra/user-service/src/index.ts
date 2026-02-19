import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";
import { createCloudRunService } from "./cloud_run.ts";
import { createCustomDomainLoadBalancer } from "./custom_domain.ts";
import { createDatabaseResources } from "./database.ts";
import { createRuntimeIdentity, grantRuntimeIam } from "./runtime_identity.ts";
import { enableProjectServices } from "./services.ts";
import {
  allowUnauthenticated,
  artifactRepoId,
  cloudRunDeletionProtection,
  customDomain,
  dbDeletionProtection,
  dbEdition,
  dbInstanceName,
  dbName,
  dbSecretName,
  dbTier,
  dbUserName,
  dbUserPassword,
  dbVersion,
  pgsWebClientId,
  pgsWebClientSecret,
  pgsWebClientSecretName,
  enableCustomDomain,
  imageTag,
  maxInstanceCount,
  minInstanceCount,
  project,
  region,
  serviceName,
  sessionTtlSeconds,
  stage
} from "./stack_config.ts";

const enabledServices = enableProjectServices(project);

const { runServiceAccount } = createRuntimeIdentity({
  project,
  serviceName,
  dependsOn: enabledServices
});

grantRuntimeIam(project, serviceName, runServiceAccount.email);

const { databaseInstance, databaseUrlSecret, databaseUrlSecretVersion } = createDatabaseResources({
  project,
  region,
  serviceName,
  dbInstanceName,
  dbName,
  dbUserName,
  dbUserPassword,
  dbTier,
  dbEdition,
  dbDeletionProtection,
  dbSecretName,
  dbVersion,
  dependsOn: enabledServices
});

let pgsWebClientSecretId: pulumi.Output<string> | undefined;
let pgsWebClientSecretVersion: gcp.secretmanager.SecretVersion | undefined;
if (pgsWebClientId && pgsWebClientSecret && pgsWebClientSecretName) {
  const pgsSecret = new gcp.secretmanager.Secret(
    pgsWebClientSecretName,
    {
      project,
      secretId: pgsWebClientSecretName,
      replication: {
        auto: {}
      }
    },
    { dependsOn: enabledServices }
  );
  pgsWebClientSecretVersion = new gcp.secretmanager.SecretVersion(
    `${pgsWebClientSecretName}-current`,
    {
      secret: pgsSecret.id,
      secretData: pgsWebClientSecret
    }
  );
  pgsWebClientSecretId = pgsSecret.secretId;
}

const { service, image } = createCloudRunService({
  project,
  region,
  serviceName,
  deletionProtection: cloudRunDeletionProtection,
  artifactRepoId,
  imageTag,
  stage,
  sessionTtlSeconds,
  minInstanceCount,
  maxInstanceCount,
  allowUnauthenticated,
  serviceAccountEmail: runServiceAccount.email,
  databaseConnectionName: databaseInstance.connectionName,
  databaseUrlSecretId: databaseUrlSecret.secretId,
  pgsWebClientId: pgsWebClientId || undefined,
  pgsWebClientSecretId,
  dependsOn: [databaseUrlSecretVersion, ...(pgsWebClientSecretVersion ? [pgsWebClientSecretVersion] : [])]
});

let customDomainIpAddress: pulumi.Output<string> | undefined;
if (enableCustomDomain) {
  customDomainIpAddress = createCustomDomainLoadBalancer({
    project,
    region,
    serviceName,
    customDomain,
    service
  });
}

export const serviceUrl = service.uri;
export const serviceAccountEmail = runServiceAccount.email;
export const deployedImage = image;
export const customDomainDnsARecord = customDomainIpAddress;
export const cloudSqlInstanceConnectionName = databaseInstance.connectionName;
export const databaseUrlSecretId = databaseUrlSecret.secretId;
export const pgsWebClientSecretResourceId = pgsWebClientSecretId;
