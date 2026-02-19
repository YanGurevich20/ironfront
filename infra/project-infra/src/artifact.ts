import * as gcp from "@pulumi/gcp";
import * as pulumi from "@pulumi/pulumi";

type ArtifactArgs = {
  project: string;
  region: string;
  artifactRepoId: string;
  artifactRepoPullProjectNumber: string;
  artifactRepoRuntimeServiceAccounts: string[];
  artifactRepoWriterServiceAccounts: pulumi.Input<string>[];
  dependsOn: gcp.projects.Service[];
};

export function createArtifactRepo(args: ArtifactArgs) {
  const artifactRepo = new gcp.artifactregistry.Repository(
    `${args.artifactRepoId}-${args.region}`,
    {
      project: args.project,
      location: args.region,
      repositoryId: args.artifactRepoId,
      description: "Ironfront container images",
      format: "DOCKER"
    },
    { dependsOn: args.dependsOn }
  );

  const artifactRepoPullMembers = [
    `serviceAccount:${args.artifactRepoPullProjectNumber}-compute@developer.gserviceaccount.com`,
    `serviceAccount:service-${args.artifactRepoPullProjectNumber}@serverless-robot-prod.iam.gserviceaccount.com`,
    ...args.artifactRepoRuntimeServiceAccounts.map((email) => `serviceAccount:${email}`)
  ];

  artifactRepoPullMembers.forEach((member, index) => {
    new gcp.artifactregistry.RepositoryIamMember(`${args.artifactRepoId}-reader-${index}`, {
      project: args.project,
      location: args.region,
      repository: artifactRepo.repositoryId,
      role: "roles/artifactregistry.reader",
      member
    });
  });

  args.artifactRepoWriterServiceAccounts.forEach((email, index) => {
    new gcp.artifactregistry.RepositoryIamMember(`${args.artifactRepoId}-writer-${index}`, {
      project: args.project,
      location: args.region,
      repository: artifactRepo.repositoryId,
      role: "roles/artifactregistry.writer",
      member: pulumi.interpolate`serviceAccount:${email}`
    });
  });

  return { artifactRepo };
}
