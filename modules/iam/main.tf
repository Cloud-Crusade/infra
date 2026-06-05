# EKS 클러스터 롤
# EKS 서비스가 AWS 리소스를 제어할 수 있도록 권한을 부여

resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-eks-cluster-role"

  # 롤 사용 주체 정의 (EKS 서비스만 허용)
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# AWS 제공 EKS 클러스터 표준 권한 연결
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# EKS 노드 롤
# 실제 워크로드를 실행하는 노드(EC2)에 부여하는 역할

resource "aws_iam_role" "eks_node" {
  name = "${var.project_name}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# 노드 기본 운영 권한
resource "aws_iam_role_policy_attachment" "eks_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node.name
}

# 파드 네트워크 통신 권한
resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node.name
}

# ECR에서 도커 이미지 꺼내올 권한
resource "aws_iam_role_policy_attachment" "eks_ecr_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node.name
}

# Lambda 롤
# Lambda 함수 실행에 필요한 최소 권한만 부여

resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# CloudWatch 로그 쓰기 권한 (직접 정의)
resource "aws_iam_policy" "lambda_logging" {
  name        = "${var.project_name}-lambda-logging-policy"
  description = "Lambda가 CloudWatch에 로그를 쓸 수 있는 최소 권한"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# 위에서 만든 로깅 정책을 Lambda 롤에 연결
resource "aws_iam_role_policy_attachment" "lambda_logging" {
  policy_arn = aws_iam_policy.lambda_logging.arn
  role       = aws_iam_role.lambda.name
}

# Secrets Manager 읽기 권한
# Lambda가 토큰 서명용 키를 Secrets Manager에서 읽을 수 있는 권한

resource "aws_iam_policy" "lambda_secrets" {
  name        = "${var.project_name}-lambda-secrets-policy"
  description = "Lambda가 Secrets Manager에서 토큰 서명 키를 읽을 수 있는 최소 권한"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      }
    ]
  })
}

# Secrets Manager 정책을 Lambda 롤에 연결
resource "aws_iam_role_policy_attachment" "lambda_secrets" {
  policy_arn = aws_iam_policy.lambda_secrets.arn
  role       = aws_iam_role.lambda.name
}

# ElastiCache(Redis) 접근 권한
# EKS 노드가 ElastiCache에 접근할 수 있는 권한

resource "aws_iam_policy" "eks_elasticache" {
  name        = "${var.project_name}-eks-elasticache-policy"
  description = "EKS 노드가 ElastiCache에 접근할 수 있는 권한"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticache:Connect",
          "elasticache:DescribeCacheClusters",
          "elasticache:DescribeReplicationGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# ElastiCache 정책을 노드 롤에 연결
resource "aws_iam_role_policy_attachment" "eks_elasticache_policy" {
  policy_arn = aws_iam_policy.eks_elasticache.arn
  role       = aws_iam_role.eks_node.name
}

# vpc_cni_role (IRSA)
# kube-system/aws-node 파드에 직접 CNI 권한 부여
# TODO: EKS 담당자에게 oidc_provider_arn, oidc_provider_url 받은 후 완성
resource "aws_iam_role" "vpc_cni" {
  name = "${var.project_name}-vpc-cni-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:aws-node"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "vpc_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni.name
}

# ebs_csi_role (IRSA)
# kube-system/ebs-csi-controller-sa 파드에 직접 EBS 권한 부여
# TODO: EKS 담당자에게 oidc_provider_arn, oidc_provider_url 받은 후 완성
resource "aws_iam_role" "ebs_csi" {
  name = "${var.project_name}-ebs-csi-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi.name
}