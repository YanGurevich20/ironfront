import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

type RuntimeIdentityArgs = {
  project: string;
  serviceName: string;
  dependsOn: gcp.projects.Service[];
};

export function createRuntimeIdentity(args: RuntimeIdentityArgs) {
  const runServiceAccount = new gcp.serviceaccount.Account(
    `${args.serviceName}-sa`,
    {
      project: args.project,
      accountId: `${args.serviceName}-sa`.slice(0, 30),
      displayName: `Service account for ${args.serviceName}`
    },
    { dependsOn: args.dependsOn }
  );

  return { runServiceAccount };
}

export function grantRuntimeIam(project: string, serviceName: string, serviceAccountEmail: pulumi.Input<string>) {
  new gcp.projects.IAMMember(`${serviceName}-cloudsql-client`, {
    project,
    role: "roles/cloudsql.client",
    member: pulumi.interpolate`serviceAccount:${serviceAccountEmail}`
  });

  new gcp.projects.IAMMember(`${serviceName}-secret-accessor`, {
    project,
    role: "roles/secretmanager.secretAccessor",
    member: pulumi.interpolate`serviceAccount:${serviceAccountEmail}`
  });
}
