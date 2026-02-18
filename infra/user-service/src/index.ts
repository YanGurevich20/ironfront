import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

const gcpCfg = new pulumi.Config("gcp");
const project = gcpCfg.require("project");
const region = gcpCfg.require("region");

const cfg = new pulumi.Config();
const serviceName = cfg.require("serviceName");
const artifactRepoId = cfg.require("artifactRepoId");
const imageTag = cfg.require("imageTag");
const stage = cfg.require("stage");
const allowUnauthenticated = cfg.requireBoolean("allowUnauthenticated");
const minInstanceCount = cfg.requireNumber("minInstanceCount");
const maxInstanceCount = cfg.requireNumber("maxInstanceCount");
const enableCustomDomain = cfg.requireBoolean("enableCustomDomain");
const customDomain = cfg.require("customDomain");

const requiredServices = [
  "run.googleapis.com",
  "cloudbuild.googleapis.com",
  "artifactregistry.googleapis.com",
  "compute.googleapis.com"
];

const enabledServices = requiredServices.map(
  (service) =>
    new gcp.projects.Service(service, {
      project,
      service,
      disableOnDestroy: false
    })
);

const runServiceAccount = new gcp.serviceaccount.Account(
  `${serviceName}-sa`,
  {
    project,
    accountId: `${serviceName}-sa`.slice(0, 30),
    displayName: `Service account for ${serviceName}`
  },
  { dependsOn: enabledServices }
);

const image = `${region}-docker.pkg.dev/${project}/${artifactRepoId}/user-service:${imageTag}`;

const service = new gcp.cloudrunv2.Service(
  serviceName,
  {
    project,
    location: region,
    name: serviceName,
    ingress: "INGRESS_TRAFFIC_ALL",
    template: {
      serviceAccount: runServiceAccount.email,
      scaling: {
        minInstanceCount,
        maxInstanceCount
      },
      containers: [
        {
          image,
          ports: { containerPort: 8080 },
          envs: [{ name: "STAGE", value: stage }]
        }
      ]
    }
  },
  { dependsOn: enabledServices }
);

if (allowUnauthenticated) {
  new gcp.cloudrunv2.ServiceIamMember("public-invoker", {
    name: service.name,
    location: region,
    project,
    role: "roles/run.invoker",
    member: "allUsers"
  });
}

let customDomainIpAddress: pulumi.Output<string> | undefined;

if (enableCustomDomain) {
  const serverlessNeg = new gcp.compute.RegionNetworkEndpointGroup(
    `${serviceName}-neg`,
    {
      project,
      region,
      networkEndpointType: "SERVERLESS",
      cloudRun: {
        service: service.name
      }
    },
    { dependsOn: [service] }
  );

  const backendService = new gcp.compute.BackendService(`${serviceName}-backend`, {
    project,
    protocol: "HTTP",
    loadBalancingScheme: "EXTERNAL_MANAGED",
    backends: [{ group: serverlessNeg.id }]
  });

  const urlMap = new gcp.compute.URLMap(`${serviceName}-urlmap`, {
    project,
    defaultService: backendService.id
  });

  const managedCert = new gcp.compute.ManagedSslCertificate(`${serviceName}-cert`, {
    project,
    managed: {
      domains: [customDomain]
    }
  });

  const httpsProxy = new gcp.compute.TargetHttpsProxy(`${serviceName}-https-proxy`, {
    project,
    urlMap: urlMap.id,
    sslCertificates: [managedCert.id]
  });

  const globalAddress = new gcp.compute.GlobalAddress(`${serviceName}-ip`, {
    project,
    ipVersion: "IPV4"
  });

  new gcp.compute.GlobalForwardingRule(`${serviceName}-https-fwd`, {
    project,
    target: httpsProxy.id,
    ipAddress: globalAddress.address,
    portRange: "443",
    loadBalancingScheme: "EXTERNAL_MANAGED"
  });

  customDomainIpAddress = globalAddress.address;
}

export const serviceUrl = service.uri;
export const serviceAccountEmail = runServiceAccount.email;
export const deployedImage = image;
export const customDomainDnsARecord = customDomainIpAddress;
