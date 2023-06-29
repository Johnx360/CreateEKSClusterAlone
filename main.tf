variable "region" {
  default = "eu-north-1" #input your aws region
}

variable "cluster_name" {
  default = "A1-EKS-cluster"
}

variable "availability_zones" {
  type = list(string)
  default = ["eu-north-1a", "eu-north-1b", "eu-north-1c"]
}

variable "private_subnets_cidrs" {
  type = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnets_cidrs" {
  type = list(string)
  default = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "4.0.1"

  name = var.cluster_name
  cidr = "10.0.0.0/16"

  azs             = var.availability_zones
  private_subnets = var.private_subnets_cidrs
  public_subnets  = var.public_subnets_cidrs

  enable_nat_gateway = true
  single_nat_gateway  = true
  enable_dns_hostnames = true

  map_public_ip_on_launch = true
}

resource "aws_security_group" "worker_group_mgmt_two" {
  name_prefix = "worker_group_mgmt_two"
  description = "worker_group_mgmt_two"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "worker_group_mgmt_two" {
  security_group_id = aws_security_group.worker_group_mgmt_two.id

  type        = "ingress"
  from_port   = 0
  to_port     = 65535
  protocol    = "tcp"
  cidr_blocks = ["10.0.0.0/8", "95.136.121.65/32"]
}

module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "19.13.1"

  cluster_name = var.cluster_name
  subnet_ids   = module.vpc.public_subnets

  tags = {
    Terraform          = "true"
    KubernetesCluster  = var.cluster_name
  }

  vpc_id = module.vpc.vpc_id

  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = true

  eks_managed_node_groups = {
    default = {
      desired_capacity = 2
      max_capacity     = 3
      min_capacity     = 1

      instance_types = ["t3.large"]
      additional_tags = {
        Terraform          = "true"
        KubernetesCluster  = var.cluster_name
      }
    }
  }
}

data "kubernetes_storage_class" "aws_ebs" {
  metadata {
    name = "aws-ebs-csi"
  }
}

resource "kubernetes_storage_class" "aws_ebs" {
  metadata {
    name = "aws-ebs-csi"
  }
  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy = "Retain"
  parameters = {
    type = "gp3"
    fsType = "ext4"
  }
}

resource "helm_release" "ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace  = "kube-system"

  set {
    name  = "enableVolumeScheduling"
    value = "true"
  }

  set {
    name  = "enableVolumeResizing"
    value = "true"
  }

  set {
    name  = "enableVolumeSnapshot"
    value = "true"
  }

  depends_on = [module.eks, null_resource.update_kubeconfig]
}

resource "null_resource" "update_kubeconfig" {
  depends_on = [module.eks]

  triggers = {
    cluster_id = module.eks.cluster_id
  }

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name} --kubeconfig kubeconfig.yaml"
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

output "cluster_name" {
  description = "The name of the EKS Cluster"
  value       = module.eks.cluster_name
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "subnet_ids" {
  description = "The IDs of the subnets"
  value       = module.vpc.public_subnets
}

output "cluster_endpoint" {
  description = "The endpoint of the EKS Cluster"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster."
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster. This is the role that provides AWS permissions to Kubernetes service accounts."
  value       = module.eks.cluster_iam_role_name
}

output "cluster_certificate_authority_data" {
  description = "Nested attribute containing certificate-authority-data for your cluster."
  value       = module.eks.cluster_certificate_authority_data
}
