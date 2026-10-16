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

## Teardown
`terraform destroy` alone is **not** enough. Deleting the cluster removes every Kubernetes
object and Auto Mode terminates its nodes, but AWS resources created by in-cluster
controllers are **not in Terraform state**. The main one is the ALB (plus target groups and
`k8s-*` security groups) created by the AWS Load Balancer Controller for the Argo CD
`argocd-server` Ingress (from the `eks-infra` repo). Once the cluster is gone nothing deletes
it, and destroy fails with `DependencyViolation` on the subnets / internet gateway / VPC.
Remove those resources **while the cluster and controller are still running**.

**1. Prerequisites**
```bash
aws sts get-caller-identity                        # write-access credentials, not the read-only token
curl https://checkip.amazonaws.com                 # must match public_access_cidrs, or kubectl can't reach the API
cp terraform.tfstate terraform.tfstate.pre-destroy # state is local and gitignored: this is the only copy
aws eks update-kubeconfig --region ap-northeast-1 --name tituseff-playground

VPC=$(aws eks describe-cluster --region ap-northeast-1 --name tituseff-playground \
  --query cluster.resourcesVpcConfig.vpcId --output text)
```

**2. Find resources created outside Terraform**
```bash
kubectl get ingress -A
kubectl get svc -A | grep LoadBalancer
kubectl get pvc -A                                  # each PVC is an EBS volume
kubectl get nodepools,nodeclasses,nodeclaims        # only the built-in general-purpose/system/default should remain
aws elbv2 describe-load-balancers --region ap-northeast-1 \
  --query "LoadBalancers[?VpcId=='$VPC'].[LoadBalancerName,State.Code]" --output table
```

**3. Delete them and wait for AWS to clean up**
```bash
kubectl -n argocd delete ingress argocd-server      # plus any LoadBalancer Services / PVCs found above

# Repeat until all three are empty
aws elbv2 describe-load-balancers --region ap-northeast-1 \
  --query "LoadBalancers[?VpcId=='$VPC'].LoadBalancerName" --output table
aws elbv2 describe-target-groups --region ap-northeast-1 \
  --query "TargetGroups[?VpcId=='$VPC'].TargetGroupName" --output table
aws ec2 describe-security-groups --region ap-northeast-1 \
  --filters Name=vpc-id,Values=$VPC Name=group-name,Values='k8s-*' \
  --query "SecurityGroups[].[GroupId,GroupName]" --output table
```
If the delete hangs, check the controller (`kubectl -n kube-system logs deploy/alb-lbc`).
Do **not** strip the finalizer, or the ALB is orphaned.

**4. Destroy (cluster first, then the rest)**
```bash
terraform destroy -target=module.eks   # lets Auto Mode nodes/ENIs drain before subnets go
terraform destroy                      # VPC, client egress NAT gateways/EIPs/subnets, endpoint
terraform state list                   # should print nothing
```

**5. Post-destroy checks**
```bash
aws logs describe-log-groups --region ap-northeast-1 --log-group-name-prefix /aws/eks/tituseff-playground  # EKS can recreate it
aws ec2 describe-addresses --region ap-northeast-1 --output table                                          # no leftover EIPs
aws ec2 describe-volumes --region ap-northeast-1 --filters Name=status,Values=available --output table     # no orphaned EBS
```

Notes:
- The client egress EIPs are released permanently. A rebuild gets new IPs, so anything
  allowlisting them must be updated, as must the hard-coded `nodeRole` in `eks-infra`'s
  `egress-test/values.yaml`.
- The KMS key enters a 30-day pending-deletion window. That is expected and free.
- To remove only the client egress (keep the cluster): delete the egress-test Argo CD apps
  first, then `terraform destroy -target=module.client_egress`.

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
