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

## Self-managed AWS Load Balancer Controller (coexistence)

This project keeps **EKS Auto Mode fully enabled**, so Auto Mode's **built-in** load
balancing capability stays on — it **cannot** be turned off without dropping Auto Mode
(the AWS provider forbids splitting the Auto Mode compute / block-storage / load-balancing
toggles). Instead, a **self-managed** AWS Load Balancer Controller is installed separately
and **coexists** with the built-in one, scoped explicitly by `IngressClass` /
`loadBalancerClass` (see *Coexistence rules* below).

### What Terraform preps here (`albcontroller.tf`)
- **Subnet discovery tags** — `kubernetes.io/role/elb = 1` on every default-VPC subnet,
  so the controller can auto-discover them for **internet-facing** ALBs/NLBs.
- **EKS Pod Identity IAM** — an IAM role (`tituseff-playground-aws-lbc`) trusting
  `pods.eks.amazonaws.com`, with the curated **AWS Load Balancer Controller** managed
  policy, plus an `aws_eks_pod_identity_association` mapping
  `kube-system/aws-load-balancer-controller` → that role. Built with the official
  [`terraform-aws-modules/eks-pod-identity`](https://registry.terraform.io/modules/terraform-aws-modules/eks-pod-identity/aws/latest)
  module (auth is **Pod Identity, not IRSA**).
- **Outputs** for the Helm project: `vpc_id`, `region`, `aws_lb_controller_role_arn`,
  `oidc_provider_arn`.

Nothing Kubernetes-side is created here (no Helm release, `IngressClass`, or
`Ingress`/`Service`). The ServiceAccount doesn't need to exist yet — Helm creates it
later and the Pod Identity association binds it to the role by name.

### Install the controller (SEPARATE project)
```bash
helm repo add eks https://aws.github.io/eks-charts && helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system \
  --set clusterName=tituseff-playground \
  --set region=ap-northeast-1 \
  --set vpcId=<vpc_id output> \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set enableServiceMutatorWebhook=false
```
- **No IRSA annotation needed.** EKS Pod Identity binds the ServiceAccount to the IAM role
  server-side; do **not** add an `eks.amazonaws.com/role-arn` annotation.
- **`serviceAccount.create=true`** so the chart creates the
  `kube-system/aws-load-balancer-controller` SA that the Pod Identity association targets.
- **`region` + `vpcId` are REQUIRED**: Auto Mode blocks IMDS, so the controller can't
  auto-discover them — feed the `region` and `vpc_id` Terraform outputs.
- **`enableServiceMutatorWebhook=false`** so the controller doesn't rewrite the default
  `loadBalancerClass`, leaving Auto Mode's built-in LB as the default (see below).

### Coexistence rules
With two controllers in the cluster, route each resource explicitly so the right one
claims it:
- **Ingress (ALB):** set `ingressClassName: alb` on the Ingress (this controller registers
  IngressClass controller `ingress.k8s.aws/alb`). Do **not** mark that IngressClass the
  cluster default, or it would silently claim Ingresses meant for the built-in controller.
- **Service (NLB):** explicitly set `loadBalancerClass: service.k8s.aws/nlb` on the Service.
  Otherwise the built-in `eks.amazonaws.com/nlb` is the **default** `loadBalancerClass` and
  the built-in controller wins.

## Notes
- The default VPC's subnets are **public**, so Auto Mode nodes get public IPs (locked-down
  Bottlerocket — no SSH/SSM). For production, use a dedicated VPC with private subnets.
- **Subnet tagging:** `kubernetes.io/role/elb = 1` is **not** needed to stand up the cluster,
  but `albcontroller.tf` adds it so the self-managed AWS Load Balancer Controller can place
  internet-facing load balancers (see *Self-managed AWS Load Balancer Controller* above).
- The applying principal is granted cluster-admin via an EKS access entry
  (`enable_cluster_creator_admin_permissions = true`), so `kubectl` works immediately.
