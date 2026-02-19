import * as gcp from "@pulumi/gcp";

type CloudRunArgs = {
  project: string;
  region: string;
  serviceName: string;
  deletionProtection: boolean;
  artifactRepoId: string;
  imageTag: string;
  stage: string;
  sessionTtlSeconds: number;
  minInstanceCount: number;
  maxInstanceCount: number;
  allowUnauthenticated: boolean;
  serviceAccountEmail: gcp.serviceaccount.Account["email"];
  databaseConnectionName: gcp.sql.DatabaseInstance["connectionName"];
  databaseUrlSecretId: gcp.secretmanager.Secret["secretId"];
  pgsWebClientId?: string;
  pgsWebClientSecretId?: gcp.secretmanager.Secret["secretId"];
  dependsOn: gcp.secretmanager.SecretVersion[];
};

export function createCloudRunService(args: CloudRunArgs) {
  const image = `${args.region}-docker.pkg.dev/${args.project}/${args.artifactRepoId}/user-service:${args.imageTag}`;
  const envs: gcp.types.input.cloudrunv2.ServiceTemplateContainerEnv[] = [
    { name: "STAGE", value: args.stage },
    { name: "SESSION_TTL_SECONDS", value: String(args.sessionTtlSeconds) },
    {
      name: "DATABASE_URL",
      valueSource: {
        secretKeyRef: {
          secret: args.databaseUrlSecretId,
          version: "latest"
        }
      }
    }
  ];
  if (args.pgsWebClientId && args.pgsWebClientSecretId) {
    envs.push({ name: "PGS_WEB_CLIENT_ID", value: args.pgsWebClientId });
    envs.push({
      name: "PGS_WEB_CLIENT_SECRET",
      valueSource: {
        secretKeyRef: {
          secret: args.pgsWebClientSecretId,
          version: "latest"
        }
      }
    });
  }

  const service = new gcp.cloudrunv2.Service(
    args.serviceName,
    {
      project: args.project,
      location: args.region,
      name: args.serviceName,
      deletionProtection: args.deletionProtection,
      ingress: "INGRESS_TRAFFIC_ALL",
      template: {
        serviceAccount: args.serviceAccountEmail,
        scaling: {
          minInstanceCount: args.minInstanceCount,
          maxInstanceCount: args.maxInstanceCount
        },
        containers: [
          {
            image,
            ports: { containerPort: 8080 },
            envs,
            volumeMounts: [
              {
                name: "cloudsql",
                mountPath: "/cloudsql"
              }
            ]
          }
        ],
        volumes: [
          {
            name: "cloudsql",
            cloudSqlInstance: {
              instances: [args.databaseConnectionName]
            }
          }
        ]
      }
    },
    { dependsOn: args.dependsOn }
  );

  if (args.allowUnauthenticated) {
    new gcp.cloudrunv2.ServiceIamMember("public-invoker", {
      name: service.name,
      location: args.region,
      project: args.project,
      role: "roles/run.invoker",
      member: "allUsers"
    });
  }

  return { service, image };
}
