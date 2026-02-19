import * as gcp from "@pulumi/gcp";

type NetworkArgs = {
  project: string;
  region: string;
  vpcName: string;
  subnetName: string;
  subnetCidr: string;
  dependsOn: gcp.projects.Service[];
};

export function createNetwork(args: NetworkArgs) {
  const network = new gcp.compute.Network(
    args.vpcName,
    {
      name: args.vpcName,
      project: args.project,
      autoCreateSubnetworks: false,
      routingMode: "REGIONAL"
    },
    { dependsOn: args.dependsOn }
  );

  const subnet = new gcp.compute.Subnetwork(
    args.subnetName,
    {
      name: args.subnetName,
      project: args.project,
      region: args.region,
      network: network.id,
      ipCidrRange: args.subnetCidr,
      privateIpGoogleAccess: true
    },
    { dependsOn: [network] }
  );

  return { network, subnet };
}
