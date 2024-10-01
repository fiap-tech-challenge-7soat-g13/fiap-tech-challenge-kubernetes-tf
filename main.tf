terraform {
  backend "s3" {
    bucket = "terraform-state-829dbe75"
    key    = "fiap-tech-challenge-kubernetes-tf"
    region = "us-east-1"
  }
}
provider "aws" {
  region = var.region
}
data "aws_vpc" "default" {
  default = true
}
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
data "aws_subnet" "default" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks_cluster_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}
resource "aws_iam_role" "eks_node_role" {
  name = "eks_node_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "eks_cluster_role_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
resource "aws_iam_role_policy_attachment" "eks_node_role_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "eks_node_role_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "eks_node_role_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
resource "aws_eks_cluster" "default" {
  name     = "default"
  role_arn = aws_iam_role.eks_cluster_role.arn
  vpc_config {
    subnet_ids = [for subnet in data.aws_subnet.default : subnet.id if subnet.availability_zone != "${var.region}e"]
  }
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }
  depends_on = [aws_iam_role_policy_attachment.eks_cluster_role_AmazonEKSClusterPolicy]
}
resource "aws_eks_node_group" "default" {
  node_group_name = "default"
  cluster_name    = aws_eks_cluster.default.name
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [for subnet in data.aws_subnet.default : subnet.id if subnet.availability_zone != "${var.region}e"]
  instance_types  = ["t3.small"]
  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }
  update_config {
    max_unavailable = 1
  }
  depends_on = [
    aws_iam_role_policy_attachment.eks_node_role_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks_node_role_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks_node_role_AmazonEC2ContainerRegistryReadOnly
  ]
}