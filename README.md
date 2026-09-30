# fleetform-infra

Terraform IaC provisioning the AWS infrastructure for
[Fleetform](https://github.com/franklynux/fleetform-apps) — a multi-cluster
GitOps platform. This repo owns cloud provisioning only; Argo CD never reads
from or has access to it.

## What this provisions

- Two isolated VPCs (hub, spoke) with non-overlapping CIDRs, public/private
  subnet split, and NAT gateway egress for private workloads
- Two EKS clusters (hub, spoke), each with a managed node group
- Remote state in S3 with native locking (Terraform 1.10+, no DynamoDB
  required)

## Structure

fleetform-infra/
├── environments/
│ └── dev/
│ ├── main.tf # hub + spoke module calls, S3 backend
│ ├── outputs.tf
│ └── variables.tf
└── modules/
└── vpc/ # reusable VPC module — parameterized by name/CIDR
├── main.tf
├── outputs.tf
└── variables.tf


The VPC module is called twice with different CIDRs (`10.0.0.0/16` for hub,
`10.1.0.0/16` for spoke) rather than duplicated as two hardcoded files — a fix
applied after an initial draft that had two copy-pasted VPC definitions.

## Usage

```bash
cd environments/dev
terraform init
terraform apply
```

Outputs `hub_cluster_name` and `spoke_cluster_name` for use with:

```bash
aws eks update-kubeconfig --name <hub_cluster_name> --alias hub --region us-east-1
aws eks update-kubeconfig --name <spoke_cluster_name> --alias spoke --region us-east-1
```

## Cost note

Two EKS control planes + two NAT gateways + four `t3.medium` nodes run
roughly $0.45–0.50/hr combined. Run `terraform destroy` between sessions if
the clusters aren't actively in use — recreation from this repo takes
~10-12 minutes.

## Related

See [`fleetform-apps`](https://github.com/franklynux/fleetform-apps) for the
GitOps layer that deploys onto these clusters.