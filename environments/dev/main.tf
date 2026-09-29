provider "aws" {
  region  = "us-east-1"
  profile = "franklynux"
}

locals {
  hub_cluster_name   = "fleetform-hub-${random_string.suffix.result}"
  spoke_cluster_name = "fleetform-spoke-${random_string.suffix.result}"
}

# --- S3 Remote Backend ---
terraform {
  backend "s3" {
    bucket  = "fleetform-tfstate-franklynux"
    key     = "dev/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
    profile = "franklynux"
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

# --- SHARED NODE IAM ROLE ---
resource "aws_iam_role" "node" {
  name = "fleetform-eks-node-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ])

  role       = aws_iam_role.node.name
  policy_arn = each.value
}

# --- HUB ---
module "hub_vpc" {
  source     = "../../modules/vpc"
  cidr_block = "10.0.0.0/16"
  vpc_name   = "hub"
}

module "hub_eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name                                     = local.hub_cluster_name
  kubernetes_version                       = "1.32"
  enable_cluster_creator_admin_permissions = true
  endpoint_public_access = true

  vpc_id     = module.hub_vpc.vpc_id
  subnet_ids = module.hub_vpc.private_subnets
}

resource "aws_eks_addon" "hub_pre_node" {
  for_each = toset(["vpc-cni", "kube-proxy", "eks-pod-identity-agent"])

  cluster_name = module.hub_eks.cluster_name
  addon_name   = each.value

  depends_on = [module.hub_eks]
}

resource "aws_eks_node_group" "hub" {
  cluster_name    = module.hub_eks.cluster_name
  node_group_name = "hub"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = module.hub_vpc.private_subnets

  instance_types = ["t3.medium"]

  scaling_config {
    min_size     = 1
    max_size     = 2
    desired_size = 2
  }

  depends_on = [aws_eks_addon.hub_pre_node, aws_iam_role_policy_attachment.node_policies]
}

resource "aws_eks_addon" "hub_coredns" {
  cluster_name = module.hub_eks.cluster_name
  addon_name   = "coredns"

  depends_on = [aws_eks_node_group.hub]
}

# --- SPOKE ---
module "spoke_vpc" {
  source     = "../../modules/vpc"
  cidr_block = "10.1.0.0/16"
  vpc_name   = "spoke"
}

module "spoke_eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name                                     = local.spoke_cluster_name
  kubernetes_version                       = "1.32"
  enable_cluster_creator_admin_permissions = true
  endpoint_public_access = true

  vpc_id     = module.spoke_vpc.vpc_id
  subnet_ids = module.spoke_vpc.private_subnets
}

resource "aws_eks_addon" "spoke_pre_node" {
  for_each = toset(["vpc-cni", "kube-proxy", "eks-pod-identity-agent"])

  cluster_name = module.spoke_eks.cluster_name
  addon_name   = each.value

  depends_on = [module.spoke_eks]
}

resource "aws_eks_node_group" "spoke" {
  cluster_name    = module.spoke_eks.cluster_name
  node_group_name = "spoke"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = module.spoke_vpc.private_subnets

  instance_types = ["t3.medium"]

  scaling_config {
    min_size     = 1
    max_size     = 2
    desired_size = 2
  }

  depends_on = [aws_eks_addon.spoke_pre_node, aws_iam_role_policy_attachment.node_policies]
}

resource "aws_eks_addon" "spoke_coredns" {
  cluster_name = module.spoke_eks.cluster_name
  addon_name   = "coredns"

  depends_on = [aws_eks_node_group.spoke]
}
