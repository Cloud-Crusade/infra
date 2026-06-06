resource "aws_eks_cluster" "this" {
  name     = "${var.PROJECT_NAME}-${var.ENVIRONMENT}-eks"
  role_arn = aws_iam_role.cluster.arn
  version  = var.CLUSTER_VERSION

  vpc_config {
    subnet_ids              = var.SUBNET_IDS
    endpoint_private_access = true
    endpoint_public_access  = var.ENDPOINT_PUBLIC_ACCESS
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
  ]

  tags = {
    Name = "${var.PROJECT_NAME}-${var.ENVIRONMENT}-eks"
  }
}

resource "aws_iam_role" "cluster" {
  name = "${var.PROJECT_NAME}-${var.ENVIRONMENT}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.PROJECT_NAME}-${var.ENVIRONMENT}-node-group"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.SUBNET_IDS
  instance_types  = var.NODE_INSTANCE_TYPES

  scaling_config {
    desired_size = var.NODE_DESIRED_SIZE
    min_size     = var.NODE_MIN_SIZE
    max_size     = var.NODE_MAX_SIZE
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_policy,
    aws_iam_role_policy_attachment.cni_policy,
    aws_iam_role_policy_attachment.ecr_policy,
  ]

  tags = {
    Name = "${var.PROJECT_NAME}-${var.ENVIRONMENT}-node-group"
  }
}

resource "aws_iam_role" "node" {
  name = "${var.PROJECT_NAME}-${var.ENVIRONMENT}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "ecr_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}
