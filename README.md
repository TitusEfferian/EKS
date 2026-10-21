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
- Terraform `>= 1.9.0` (cross-variable validation for the module toggles).
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

## Module toggles
Each root module has a bool toggle, and the defaults in `variables.tf` are the source of truth:
`enable_vpc`, `enable_eks`, `enable_route53_domain`, `enable_nifi_ingress` and `enable_nifi_dns`
default to `true`; `enable_client_egress` defaults to `false`. Flip a default in `variables.tf`
(via PR) and `terraform apply` creates or destroys that module. Don't set these in `terraform.tfvars`,
because a value there silently overrides the default.
**Exception:** `enable_route53_domain` buys a domain and is guarded by `prevent_destroy`, so
flipping it back to `false` makes the plan fail instead of deregistering it (see
[Domain registration](#domain-registration-route-53-domains)). The cluster
and the client egress both live inside the VPC, so `enable_eks` / `enable_client_egress`
require `enable_vpc = true` (enforced by variable validation).

Recommended teardown order:
1. Delete Kubernetes `Ingress` / `Service type=LoadBalancer` objects first so Auto Mode
   removes its ALBs/ENIs (see Teardown step 3 below).
2. `terraform apply -var enable_eks=false -var enable_client_egress=false`
3. `terraform apply -var enable_vpc=false -var enable_eks=false -var enable_client_egress=false`

Disabling `enable_client_egress` releases the Elastic IPs; re-enabling allocates new IPs,
so client allowlists must be updated.

## Domain registration (Route 53 Domains)
`./modules/route53` registers `titusefferian.dev` (`domain_name`) for `domain_duration_in_years`
(default 1) with auto-renew on, using the raw `aws_route53domains_domain` resource (no
terraform-aws-modules module supports registration). It then adopts the public hosted zone
Route 53 auto-creates at registration via
[`terraform-aws-modules/route53`](https://registry.terraform.io/modules/terraform-aws-modules/route53/aws/6.5.1)
`6.5.1` with `create_zone = false`, so the domain stays delegated to that one zone and
`domain_records` are managed there. The Route 53 Domains API is **us-east-1 only**, so the module
runs on the `aws.us_east_1` provider alias (`providers.tf`).

> [!WARNING]
> `enable_route53_domain = true` + `terraform apply` **purchases the domain**. Registration is
> **non-refundable**, and auto-renew bills the account every year until you turn it off.

**Before enabling — check availability and price:**
```bash
aws route53domains check-domain-availability --domain-name titusefferian.dev --region us-east-1
aws route53domains list-prices --tld dev --region us-east-1
```

**Enable:** set `enable_route53_domain = true` and fill `domain_contact` in the gitignored
`terraform.tfvars` (placeholders in `terraform.tfvars.example`). **Never commit real contact
details — this repo is public.** WHOIS privacy is enabled for every contact and the transfer
lock is on.

**After apply:**
- **Verify the registrant email.** AWS sends a verification link; if it isn't clicked within
  ~15 days the domain is suspended. Check status with:
  ```bash
  aws route53domains get-contact-reachability-status --domain-name titusefferian.dev --region us-east-1
  ```
- Registration is asynchronous and can take up to ~an hour (create timeout is 60m). Track it with
  `aws route53domains list-operations --region us-east-1`.
- `.dev` is on the **HSTS preload list**: browsers only connect over HTTPS, so anything served on
  this domain needs a TLS certificate (e.g. ACM) — plain HTTP will never work.

**Teardown / prevent_destroy:** `aws_route53domains_domain` has `lifecycle { prevent_destroy = true }`.
`terraform destroy` or `enable_route53_domain = false` therefore **errors** instead of
deregistering. Destroying the resource deregisters the domain with **no refund**. If you really
want to give it up, either turn off auto-renew and let it expire (`domain_auto_renew = false`),
or remove the `prevent_destroy` guard deliberately and then destroy. After deregistration, the
auto-created hosted zone may be left behind (and keep billing ~$0.50/month): delete its records
and the zone manually with `aws route53 delete-hosted-zone`.

## NiFi ingress (ACM certificate + Route 53 alias)
`./modules/nifi-ingress` issues a DNS-validated ACM certificate for `nifi.titusefferian.dev`
(`nifi_domain_name`) with
[`terraform-aws-modules/acm`](https://registry.terraform.io/modules/terraform-aws-modules/acm/aws/6.3.1)
`6.3.1`, and points that name at the NiFi Ingress ALB with an alias `A` record via
[`terraform-aws-modules/route53`](https://registry.terraform.io/modules/terraform-aws-modules/route53/aws/6.5.1)
`6.5.1` (`create_zone = false`). Both go into the existing `domain_name` hosted zone, looked up
by name, so the zone must already exist. The certificate is created in `ap-northeast-1` (default
provider) because the ALB that uses it is in Tokyo. No `AAAA` record: the ALB is IPv4-only.

The ALB is created by the AWS Load Balancer Controller from the eks-infra NiFi Ingress, which
needs the certificate ARN first, so this is a **two-stage apply**:

**Stage 1 — certificate.** `enable_nifi_ingress` defaults to `true` in `variables.tf`, so a plain
`terraform apply` creates
the certificate and its validation CNAME and waits (up to 30m) for it to be `ISSUED`. Then, in
eks-infra `nifi/values.yaml`:
- set `ingress.certificateArn` to the output of `terraform output nifi_acm_certificate_arn`,
- set `ingress.enabled: true`.

The ALB name is pinned by `ingress.loadBalancerName` (rendered as the
`alb.ingress.kubernetes.io/load-balancer-name` annotation) to `tituseff-playground-nifi`,
which is also the `nifi_alb_name` default here; keep the two in sync (max 32 characters).

**Stage 2 — DNS.** `enable_nifi_dns` now defaults to `true` in `variables.tf`, so once Argo CD
has synced and the ALB exists, a plain `terraform apply` handles it.
This creates the alias `A` record `nifi.titusefferian.dev -> ALB`.

Caveats:
- `data "aws_lb"` **errors if the ALB does not exist**. Set `enable_nifi_dns = false` and apply
  **before** deleting the Ingress (or tearing down the cluster), otherwise every plan fails.
- **Keep the ACM validation CNAME** in the zone: ACM needs it to auto-renew the certificate.
- **Don't run ExternalDNS for this hostname** at the same time; two writers would fight over
  the record.

## Teardown

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
