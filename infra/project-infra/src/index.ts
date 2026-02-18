import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

const cfg = new pulumi.Config("gcp");
const project = cfg.require("project");
const region = cfg.require("region");

const stackCfg = new pulumi.Config();
const artifactRepoId = stackCfg.require("artifactRepoId");
const vpcName = stackCfg.require("vpcName");
const subnetName = stackCfg.require("subnetName");
const subnetCidr = stackCfg.require("subnetCidr");

const requiredServices = [
  "artifactregistry.googleapis.com",
  "compute.googleapis.com",
  "servicenetworking.googleapis.com"
];

const enabledServices = requiredServices.map(
	(service) =>
		new gcp.projects.Service(service, {
			service,
			project,
			disableOnDestroy: false
		})
);

const network = new gcp.compute.Network(
  vpcName,
  {
    name: vpcName,
    project,
    autoCreateSubnetworks: false,
    routingMode: "REGIONAL"
  },
  { dependsOn: enabledServices }
);

const subnet = new gcp.compute.Subnetwork(
  subnetName,
  {
    name: subnetName,
    project,
    region,
    network: network.id,
    ipCidrRange: subnetCidr,
    privateIpGoogleAccess: true
  },
  { dependsOn: [network] }
);

const artifactRepo = new gcp.artifactregistry.Repository(
  `${artifactRepoId}-${region}`,
  {
    project,
    location: region,
    repositoryId: artifactRepoId,
    description: "Ironfront container images",
    format: "DOCKER"
  },
  { dependsOn: enabledServices }
);

export const gcpProject = project;
export const gcpRegion = region;
export const vpcId = network.id;
export const subnetworkId = subnet.id;
export const artifactRegistryRepository = artifactRepo.id;
