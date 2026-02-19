import * as gcp from "@pulumi/gcp";

export const requiredServices = [
  "artifactregistry.googleapis.com",
  "cloudbuild.googleapis.com",
  "compute.googleapis.com",
  "iam.googleapis.com",
  "servicenetworking.googleapis.com",
  "storage.googleapis.com",
  "logging.googleapis.com"
];

export function enableProjectServices(project: string) {
  return requiredServices.map(
    (service) =>
      new gcp.projects.Service(service, {
        service,
        project,
        disableOnDestroy: false
      })
  );
}
