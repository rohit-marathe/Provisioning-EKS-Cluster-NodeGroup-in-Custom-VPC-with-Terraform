# Define a variable to control ELB destruction
variable "destroy_elb" {
  description = "Set to true if ELB should be destroyed"
  default     = true
}

# VPC
resource "aws_vpc" "eks_vpc" {
  cidr_block           = "180.100.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Internet Gateway
resource "aws_internet_gateway" "eks_igw" {
  vpc_id = aws_vpc.eks_vpc.id
}

# Public Subnet 1
resource "aws_subnet" "eks_subnet_az1" {
  count               = 1
  cidr_block          = "180.100.1.0/24"
  vpc_id              = aws_vpc.eks_vpc.id
  availability_zone   = "us-west-1b"
  map_public_ip_on_launch = true
}

# Public Subnet 2
resource "aws_subnet" "eks_subnet_az2" {
  count               = 1
  cidr_block          = "180.100.2.0/24"
  vpc_id              = aws_vpc.eks_vpc.id
  availability_zone   = "us-west-1c"
  map_public_ip_on_launch = true
}

# Route Table for Public Subnets
resource "aws_route_table" "eks_route_table" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_igw.id
  }
}

# Route Table Associate for Public Subnet 1
resource "aws_route_table_association" "eks_route_table_association_az1" {
  subnet_id      = aws_subnet.eks_subnet_az1[0].id
  route_table_id = aws_route_table.eks_route_table.id
}

# Route Table Associate for Public Subnet 2
resource "aws_route_table_association" "eks_route_table_association_az2" {
  subnet_id      = aws_subnet.eks_subnet_az2[0].id
  route_table_id = aws_route_table.eks_route_table.id
}

# Security Group
resource "aws_security_group" "eks_security_group" {
  name        = "eks-security-group"
  description = "Allow all inbound traffic"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Elastic Load Balancer (ELB)
resource "aws_lb" "eks_lb" {
  count = var.destroy_elb ? 1 : 0
  name               = "eks-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.eks_subnet_az1[0].id, aws_subnet.eks_subnet_az2[0].id]
  enable_deletion_protection = false
}

# EKS Cluster depends on ELB
resource "aws_eks_cluster" "eks_cluster" {
  depends_on = [aws_lb.eks_lb]
  name       = "my-cluster"
  role_arn   = "arn:aws:iam::YOUR-ARN-NUMBER:role/My-EKS-Role"  # Replace with your actual ARN
  vpc_config {
    subnet_ids         = [aws_subnet.eks_subnet_az1[0].id, aws_subnet.eks_subnet_az2[0].id]
    security_group_ids = [aws_security_group.eks_security_group.id]
  }
}


# EKS Node Group depends on EKS Cluster
resource "aws_eks_node_group" "eks_nodes" {
  depends_on       = [aws_eks_cluster.eks_cluster]
  cluster_name     = aws_eks_cluster.eks_cluster.name
  node_group_name  = "my-eks-node-group"
  node_role_arn    = "arn:aws:iam::YOUR-ARN-NUMBER:role/My-Eks-Nodegroup"  # Replace with your actual ARN
  subnet_ids       = [aws_subnet.eks_subnet_az1[0].id, aws_subnet.eks_subnet_az2[0].id]
  instance_types   = ["t3.medium"]
  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }
  remote_access {
    ec2_ssh_key = "YOUR-KEY-NAME"  # Replace with your actual key pair name
  }
}

# Outputs
output "vpc_id" {
  value = aws_vpc.eks_vpc.id
}

output "eks_cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}