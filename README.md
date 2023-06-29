# CreateEKSClusterAlone
This Terraform script is used to set up an Amazon EKS (Elastic Kubernetes Service) cluster on AWS.

# Create EKS Cluster on AWS
This Terraform script is used to set up an Amazon EKS (Elastic Kubernetes Service) cluster on AWS. Here's the block by block description:

**Variables**

```
variable "region" {...}
variable "cluster_name" {...}
variable "availability_zones" {...}
variable "private_subnets_cidrs" {...}
variable "public_subnets_cidrs" {...}
```

These are the variables used in the script. These include AWS region, cluster name, availability zones, CIDR blocks for private and public subnets. You can either provide these values while running the script or let it use the default ones.

**Terraform Block**

`terraform {...}`

This block is used to specify required providers for our Terraform script. Here, we are using three providers: AWS, Kubernetes, and Helm, and their required versions are also mentioned.

**Provider Block**

`provider "aws" {...}`
The AWS provider block is used to configure the AWS credentials. It uses the region variable to specify the AWS region.

**VPC Module**

`module "vpc" {...}`
This module is used to create a VPC (Virtual Private Cloud) with the help of the terraform-aws-modules/vpc/aws module. It includes variables like availability zones, private and public subnet CIDRs, NAT gateway settings, and DNS hostnames settings.

**Security Group and Security Group Rule Resources**

```
resource "aws_security_group" "worker_group_mgmt_two" {...}
resource "aws_security_group_rule" "worker_group_mgmt_two" {...}
```

These blocks create a security group and security group rule which allow ingress (incoming) traffic on all TCP ports from the specified CIDR blocks.

**EKS Module**

`module "eks" {...}`
This module is used to create an EKS cluster with the help of the terraform-aws-modules/eks/aws module. It uses variables like the cluster name, subnet IDs, VPC ID, node group configurations, etc.

**Null Resource**

`resource "null_resource" "update_kubeconfig" {...}`
This is a resource that performs a local action: updating the kubeconfig file using aws eks update-kubeconfig command after the EKS cluster has been created.

**Kubernetes Provider**

`provider "kubernetes" {...}`
The Kubernetes provider block is used to interact with the Kubernetes cluster that was created in the previous steps.

**Outputs**

```
output "cluster_name" {...}
output "vpc_id" {...}
output "subnet_ids" {...}
output "cluster_endpoint" {...}
output "cluster_security_group_id" {...}
output "cluster_iam_role_name" {...}
output "cluster_certificate_authority_data" {...}
```

These output blocks will show the resulting cluster name, VPC ID, subnet IDs, cluster endpoint, security group ID, IAM role name, and certificate authority data after the EKS cluster has been successfully created.

Before running this script, make sure that you have AWS CLI configured with valid AWS credentials and you have necessary permissions to create resources in AWS. You can apply this configuration by running terraform init followed by terraform apply in your terminal.
