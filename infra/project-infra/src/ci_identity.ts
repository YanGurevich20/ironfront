import * as gcp from "@pulumi/gcp";

type CiIdentityArgs = {
  project: string;
  ciServiceAccountId: string;
  dependsOn: gcp.projects.Service[];
};

export function createCiServiceAccount(args: CiIdentityArgs) {
  const serviceAccount = new gcp.serviceaccount.Account(
    `${args.ciServiceAccountId}-sa`,
    {
      project: args.project,
      accountId: args.ciServiceAccountId,
      displayName: "Ironfront CI"
    },
    { dependsOn: args.dependsOn }
  );

  return { serviceAccount };
}
