import * as gcp from "@pulumi/gcp";

const requiredServices = [
  "run.googleapis.com",
  "cloudbuild.googleapis.com",
  "artifactregistry.googleapis.com",
  "compute.googleapis.com",
  "sqladmin.googleapis.com",
  "secretmanager.googleapis.com"
];

export function enableProjectServices(project: string) {
  return requiredServices.map(
    (service) =>
      new gcp.projects.Service(service, {
        project,
        service,
        disableOnDestroy: false
      })
  );
}
