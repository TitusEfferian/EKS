# modules/EKS

Local child module that provisions an **Amazon EKS Auto Mode** cluster in an existing
VPC/subnets, plus the **AWS Load Balancer Controller** prerequisites (EKS Pod Identity role
and public-subnet discovery tags). This module owns all the actual cluster/controller
resources; the repo root just calls it and re-exposes its outputs.

## What this creates
- `data.aws_vpc.default` / `data.aws_subnets.default` — discovers the default VPC and its
  subnets in the caller's configured region.
- `module.eks` (`terraform-aws-modules/eks/aws`, `21.24.0`) — the EKS Auto Mode cluster,
  including the cluster IAM role and Auto Mode node IAM role (created automatically by the
  module with the correct managed policies).
- `module.aws_lb_controller_pod_identity` (`terraform-aws-modules/eks-pod-identity/aws`,
  `~> 2.8`) — IAM role + EKS Pod Identity association for the AWS Load Balancer Controller's
  `aws-load-balancer-controller` ServiceAccount in `kube-system`.
- `aws_ec2_tag.subnet_elb_role` / `aws_ec2_tag.subnet_cluster` — tags every discovered subnet
  so the controller can auto-discover them for internet-facing ALBs.

## Inputs

| Name                   | Description                                                                                                          | Type           | Default                            | Required |
|------------------------|-----------------------------------------------------------------------------------------------------------------------|----------------|-------------------------------------|:--------:|
| `cluster_name`         | Name of the EKS cluster. Also used as the prefix for the IAM roles and security groups the module creates.           | `string`       | n/a                                 |   yes    |
| `kubernetes_version`   | Kubernetes control-plane version for the EKS cluster. Leave null to fall back to the underlying module's own default. | `string`       | `null`                              |    no    |
| `node_pools`           | Built-in EKS Auto Mode (AWS-managed Karpenter) node pools to enable. Valid values: `general-purpose`, `system`.       | `list(string)` | `["general-purpose", "system"]`     |    no    |
| `public_access_cidrs`  | CIDR blocks allowed to reach the cluster's PUBLIC Kubernetes API endpoint. Must be valid CIDRs and cannot include `0.0.0.0/0`. | `list(string)` | n/a                         |   yes    |
| `tags`                 | Tags applied to every resource created by this module.                                                                | `map(string)`  | `{}`                                |    no    |

## Outputs

| Name                                   | Description                                                                                                     |
|-----------------------------------------|-------------------------------------------------------------------------------------------------------------|
| `cluster_name`                          | EKS cluster name.                                                                                              |
| `cluster_arn`                           | EKS cluster ARN.                                                                                                |
| `cluster_endpoint`                      | Endpoint for the Kubernetes API server.                                                                        |
| `cluster_certificate_authority_data`    | Base64-encoded certificate authority data for the cluster.                                                     |
| `cluster_security_group_id`             | Security group ID attached to the EKS control plane.                                                           |
| `node_iam_role_arn`                     | IAM role ARN used by the EKS Auto Mode nodes.                                                                   |
| `lbc_pod_identity_role_arn`             | IAM role ARN assumed by the AWS Load Balancer Controller via EKS Pod Identity. Shown for reference/verification. |

## Notes
- `region` is intentionally **not** an input here — the AWS provider (region + default tags)
  is configured once, at the repo root, and inherited by this module automatically.
- `configure_kubectl` (which needs `var.region`) is not produced by this module; it's built at
  the root from `var.region` and this module's `cluster_name` output.
