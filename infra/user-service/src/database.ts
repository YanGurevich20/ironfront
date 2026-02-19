import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

type DatabaseArgs = {
  project: string;
  region: string;
  serviceName: string;
  dbInstanceName: string;
  dbName: string;
  dbUserName: string;
  dbUserPassword: pulumi.Input<string>;
  dbTier: string;
  dbEdition: string;
  dbDeletionProtection: boolean;
  dbSecretName: string;
  dbVersion: string;
  dependsOn: gcp.projects.Service[];
};

export function createDatabaseResources(args: DatabaseArgs) {
  const databaseInstance = new gcp.sql.DatabaseInstance(
    args.dbInstanceName,
    {
      project: args.project,
      region: args.region,
      name: args.dbInstanceName,
      databaseVersion: args.dbVersion,
      deletionProtection: args.dbDeletionProtection,
      settings: {
        edition: args.dbEdition,
        tier: args.dbTier,
        availabilityType: "ZONAL",
        diskType: "PD_SSD",
        diskSize: 20,
        backupConfiguration: {
          enabled: true,
          pointInTimeRecoveryEnabled: true
        }
      }
    },
    { dependsOn: args.dependsOn }
  );

  new gcp.sql.Database(`${args.dbInstanceName}-${args.dbName}`, {
    project: args.project,
    name: args.dbName,
    instance: databaseInstance.name
  });

  new gcp.sql.User(`${args.dbInstanceName}-${args.dbUserName}`, {
    project: args.project,
    instance: databaseInstance.name,
    name: args.dbUserName,
    password: args.dbUserPassword
  });

  const databaseUrlSecret = new gcp.secretmanager.Secret(
    args.dbSecretName,
    {
      project: args.project,
      secretId: args.dbSecretName,
      replication: {
        auto: {}
      }
    },
    { dependsOn: args.dependsOn }
  );

  const databaseUrl = pulumi
    .all([databaseInstance.connectionName, args.dbUserPassword])
    .apply(([connectionName, password]) => {
      const encodedPassword = encodeURIComponent(password);
      return `postgresql://${args.dbUserName}:${encodedPassword}@/${args.dbName}?host=/cloudsql/${connectionName}`;
    });

  const databaseUrlSecretVersion = new gcp.secretmanager.SecretVersion(
    `${args.dbSecretName}-current`,
    {
      secret: databaseUrlSecret.id,
      secretData: databaseUrl
    }
  );

  return {
    databaseInstance,
    databaseUrlSecret,
    databaseUrlSecretVersion
  };
}
