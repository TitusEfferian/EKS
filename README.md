# EKS Auto Mode — `tituseff-playground`

Minimal Terraform that stands up an **Amazon EKS Auto Mode** cluster in the existing
**default VPC** (`ap-northeast-1`) using the official
[`terraform-aws-modules/eks`](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
module. Only the cluster is managed here — no Kubernetes/`kubectl` resources (custom
NodePools, add-ons, etc. come later in a separate project).

## What this creates
- An EKS cluster (`tituseff-playground`, Kubernetes `1.36`) with **Auto Mode** enabled
  (`general-purpose` + `system` built-in node pools).
- The **cluster IAM role** and **Auto Mode node IAM role**, created automatically by the
  module with the correct managed policies (no custom IAM in this code).
- API endpoint: **public + private**, with public access restricted to your IP allowlist.

In Auto Mode, AWS fully manages compute (Karpenter), block storage, and load balancing —
you do **not** install Karpenter, CRDs, or add-ons to bring the cluster up.

## Prerequisites
- Terraform `>= 1.5.7`.
- AWS provider `~> 6.0` (pinned in `versions.tf`, fetched by `terraform init`).
- **AWS credentials with write access.** The read-only token used for discovery cannot
  create resources — authenticate as an admin/PowerUser principal before `apply`.

## Usage
```bash
terraform init
terraform plan
terraform apply
```

After apply, point `kubectl` at the cluster (also emitted as the `configure_kubectl` output):
```bash
aws eks update-kubeconfig --region ap-northeast-1 --name tituseff-playground
```

## Customize
`terraform.tfvars` is gitignored (keeps your IP out of this public repo). Copy the example and edit:
```bash
cp terraform.tfvars.example terraform.tfvars
```
Then set in `terraform.tfvars`:
- `public_access_cidrs` — your workstation IP (`curl https://checkip.amazonaws.com`), e.g. `["1.2.3.4/32"]`.
- `cluster_name`, `kubernetes_version`, `node_pools`, `region`.

## Notes
- The default VPC's subnets are **public**, so Auto Mode nodes get public IPs (locked-down
  Bottlerocket — no SSH/SSM). For production, use a dedicated VPC with private subnets.
- **No subnet tagging** is required to stand up the cluster. `kubernetes.io/role/elb` style
  tags only matter later if you expose `LoadBalancer`/`Ingress` resources.
- The applying principal is granted cluster-admin via an EKS access entry
  (`enable_cluster_creator_admin_permissions = true`), so `kubectl` works immediately.
