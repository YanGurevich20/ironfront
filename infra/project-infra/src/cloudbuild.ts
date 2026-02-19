import * as gcp from "@pulumi/gcp";
import * as pulumi from "@pulumi/pulumi";

type CloudBuildIamArgs = {
  project: string;
  cloudBuildSourceBucket: string;
  cloudBuildBucketObjectAdminServiceAccounts: pulumi.Input<string>[];
  cloudBuildLogWriterServiceAccounts: pulumi.Input<string>[];
};

export function applyCloudBuildIam(args: CloudBuildIamArgs) {
  args.cloudBuildBucketObjectAdminServiceAccounts.forEach((email, index) => {
    new gcp.storage.BucketIAMMember(`cloudbuild-bucket-object-admin-${index}`, {
      bucket: args.cloudBuildSourceBucket,
      role: "roles/storage.objectAdmin",
      member: pulumi.interpolate`serviceAccount:${email}`
    });
  });

  args.cloudBuildLogWriterServiceAccounts.forEach((email, index) => {
    new gcp.projects.IAMMember(`cloudbuild-log-writer-${index}`, {
      project: args.project,
      role: "roles/logging.logWriter",
      member: pulumi.interpolate`serviceAccount:${email}`
    });
  });
}
