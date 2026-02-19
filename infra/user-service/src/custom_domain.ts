import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

type CustomDomainArgs = {
  project: string;
  region: string;
  serviceName: string;
  customDomain: string;
  service: gcp.cloudrunv2.Service;
};

export function createCustomDomainLoadBalancer(args: CustomDomainArgs): pulumi.Output<string> {
  const serverlessNeg = new gcp.compute.RegionNetworkEndpointGroup(
    `${args.serviceName}-neg`,
    {
      project: args.project,
      region: args.region,
      networkEndpointType: "SERVERLESS",
      cloudRun: {
        service: args.service.name
      }
    },
    { dependsOn: [args.service] }
  );

  const backendService = new gcp.compute.BackendService(`${args.serviceName}-backend`, {
    project: args.project,
    protocol: "HTTP",
    loadBalancingScheme: "EXTERNAL_MANAGED",
    backends: [{ group: serverlessNeg.id }]
  });

  const urlMap = new gcp.compute.URLMap(`${args.serviceName}-urlmap`, {
    project: args.project,
    defaultService: backendService.id
  });

  const managedCert = new gcp.compute.ManagedSslCertificate(`${args.serviceName}-cert`, {
    project: args.project,
    managed: {
      domains: [args.customDomain]
    }
  });

  const httpsProxy = new gcp.compute.TargetHttpsProxy(`${args.serviceName}-https-proxy`, {
    project: args.project,
    urlMap: urlMap.id,
    sslCertificates: [managedCert.id]
  });

  const globalAddress = new gcp.compute.GlobalAddress(`${args.serviceName}-ip`, {
    project: args.project,
    ipVersion: "IPV4"
  });

  new gcp.compute.GlobalForwardingRule(`${args.serviceName}-https-fwd`, {
    project: args.project,
    target: httpsProxy.id,
    ipAddress: globalAddress.address,
    portRange: "443",
    loadBalancingScheme: "EXTERNAL_MANAGED"
  });

  return globalAddress.address;
}
