# ==============================
# 롤 정의 (aws_iam_role)
# ==============================

# EKS 클러스터 롤
# EKS 서비스가 AWS 리소스를 제어할 수 있도록 권한을 부여
resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-eks-cluster-role"

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

# vpc_cni 롤 (IRSA)
# kube-system/aws-node 파드에 직접 CNI 권한 부여
# TODO: EKS 담당자에게 oidc_provider_arn, oidc_provider_url 받은 후 완성
# resource "aws_iam_role" "vpc_cni" {
#   name = "${var.project_name}-vpc-cni-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Federated = var.oidc_provider_arn
#         }
#         Action = "sts:AssumeRoleWithWebIdentity"
#         Condition = {
#           StringEquals = {
#             "${var.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:aws-node"
#           }
#         }
#       }
#     ]
#   })
# }

# ebs_csi 롤 (IRSA)
# kube-system/ebs-csi-controller-sa 파드에 직접 EBS 권한 부여
# TODO: EKS 담당자에게 oidc_provider_arn, oidc_provider_url 받은 후 완성
# resource "aws_iam_role" "ebs_csi" {
#   name = "${var.project_name}-ebs-csi-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Federated = var.oidc_provider_arn
#         }
#         Action = "sts:AssumeRoleWithWebIdentity"
#         Condition = {
#           StringEquals = {
#             "${var.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
#           }
#         }
#       }
#     ]
#   })
# }

# ==============================
# 정책 정의 (aws_iam_policy)
# ==============================

# CloudWatch 로그 쓰기 권한
resource "aws_iam_policy" "lambda_logging" {
  name        = "${var.project_name}-lambda-logging-policy"
  description = "Lambda minimum policy for CloudWatch logging"

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

# Secrets Manager 읽기 권한
resource "aws_iam_policy" "lambda_secrets" {
  name        = "${var.project_name}-lambda-secrets-policy"
  description = "Lambda minimum policy for Secrets Manager read"

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

# SQS 소비 권한 (persistence 람다 event source mapping)
resource "aws_iam_policy" "lambda_sqs" {
  name        = "${var.project_name}-lambda-sqs-policy"
  description = "Lambda SQS consume (event source mapping)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = "*"
      }
    ]
  })
}

# ElastiCache 접근 권한
resource "aws_iam_policy" "eks_elasticache" {
  name        = "${var.project_name}-eks-elasticache-policy"
  description = "EKS node minimum policy for ElastiCache access"

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

# ==============================
# 정책 연결 (aws_iam_role_policy_attachment)
# ==============================

# EKS 클러스터 롤 연결
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# EKS 노드 롤 연결
resource "aws_iam_role_policy_attachment" "eks_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "eks_ecr_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "eks_elasticache_policy" {
  policy_arn = aws_iam_policy.eks_elasticache.arn
  role       = aws_iam_role.eks_node.name
}

# Lambda 롤 연결
resource "aws_iam_role_policy_attachment" "lambda_logging" {
  policy_arn = aws_iam_policy.lambda_logging.arn
  role       = aws_iam_role.lambda.name
}

resource "aws_iam_role_policy_attachment" "lambda_secrets" {
  policy_arn = aws_iam_policy.lambda_secrets.arn
  role       = aws_iam_role.lambda.name
}

resource "aws_iam_role_policy_attachment" "lambda_sqs" {
  policy_arn = aws_iam_policy.lambda_sqs.arn
  role       = aws_iam_role.lambda.name
}

# VPC 연결 람다용 ENI 권한 (ElastiCache/RDS 등 VPC 내부 접근 시)
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = aws_iam_role.lambda.name
}

# IRSA 롤 연결
# resource "aws_iam_role_policy_attachment" "vpc_cni_policy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
#   role       = aws_iam_role.vpc_cni.name
# }

# resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
#   role       = aws_iam_role.ebs_csi.name
# }