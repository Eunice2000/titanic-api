
# ────────────────────────────────────────────────────────────────
# Data Sources
# ────────────────────────────────────────────────────────────────

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# ────────────────────────────────────────────────────────────────
# VPC Module
# ────────────────────────────────────────────────────────────────

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true   # cost saving
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ────────────────────────────────────────────────────────────────
# Security Groups
# ────────────────────────────────────────────────────────────────

resource "aws_security_group" "eks_nodes" {
  name        = "${var.project_name}-eks-nodes-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-eks-nodes-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# ────────────────────────────────────────────────────────────────
# EKS Cluster
# ────────────────────────────────────────────────────────────────

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    main = {
      name           = "main"
      min_size       = 1
      max_size       = 3
      desired_size   = 1

      instance_types = [var.node_instance_type]  # t4g.small
      capacity_type  = "SPOT"

      ami_type = "AL2023_ARM_64"

      labels = {
        role = "general"
      }

      # Taint block - uncomment if needed
      # taints = [
      #   {
      #     key    = "dedicated"
      #     value  = "titanic-api"
      #     effect = "NO_SCHEDULE"
      #   }
      # ]

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 20
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 125
            encrypted             = true
            delete_on_termination = true
          }
        }
      }
    }
  }

  enable_irsa = true

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ────────────────────────────────────────────────────────────────
# RDS PostgreSQL
# ────────────────────────────────────────────────────────────────

resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_subnet_group" "rds" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_db_instance" "postgres" {
  identifier             = "${var.project_name}-postgres"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = "titanic"
  username               = "titanic_user"
  password               = random_password.db_password.result
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  skip_final_snapshot    = true   # for demo – change in real prod
  multi_az               = var.db_multi_az

  tags = {
    Name        = "${var.project_name}-postgres"
    Environment = var.environment
  }
}

# ────────────────────────────────────────────────────────────────
# Secrets Manager – only for RDS password
# ────────────────────────────────────────────────────────────────

resource "aws_secretsmanager_secret" "rds_password" {
  name        = "/${var.project_name}/${var.environment}/rds/password"
  description = "PostgreSQL password for Titanic API RDS"
}

resource "aws_secretsmanager_secret_version" "rds_password" {
  secret_id     = aws_secretsmanager_secret.rds_password.id
  secret_string = random_password.db_password.result
}

# ────────────────────────────────────────────────────────────────
# ECR Repository
# ────────────────────────────────────────────────────────────────

resource "aws_ecr_repository" "titanic_api" {
  name                 = "titanic-api"
  image_tag_mutability = "MUTABLE"  # Change to IMMUTABLE in strict prod

  image_scanning_configuration {
    scan_on_push = true  # Security best practice
  }

  tags = {
    Name        = "${var.project_name}-ecr"
    Environment = var.environment
  }
}

# Lifecycle policy: expire old images (cost + security)
resource "aws_ecr_lifecycle_policy" "titanic_api" {
  repository = aws_ecr_repository.titanic_api.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 20 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["latest", "v"]
          countType     = "imageCountMoreThan"
          countNumber   = 20
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# ────────────────────────────────────────────────────────────────
# IAM Role for GitHub Actions
# ────────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "github_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [
        "repo:Eunice2000/titanic-api:*"
      ]
    }
  }
}

resource "aws_iam_role" "github_ecr_push" {
  name               = "github-actions-ecr-push-role"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json

  tags = {
    Name        = "${var.project_name}-github-ecr-role"
    Environment = var.environment
  }
}

# Policy: ECR push/pull permissions
data "aws_iam_policy_document" "ecr_push_policy" {
  statement {
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:TagResource",
      "ecr:BatchDeleteImage"
    ]

    resources = [aws_ecr_repository.titanic_api.arn]
  }
}

resource "aws_iam_role_policy" "ecr_push" {
  name   = "ecr-push-policy"
  role   = aws_iam_role.github_ecr_push.id
  policy = data.aws_iam_policy_document.ecr_push_policy.json
}

# Policy: EKS access permissions (UPDATED with more permissions)
data "aws_iam_policy_document" "eks_access_policy" {
  statement {
    effect = "Allow"

    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters"
    ]

    # Restrict to your specific cluster
    resources = [
      "arn:aws:eks:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
    ]
  }
  
  statement {
    effect = "Allow"
    
    actions = [
      "eks:UpdateKubeconfig",
      "eks:AccessKubernetesApi"  # NEW: Required for API access
    ]
    
    resources = ["*"]  # These actions don't support resource-level permissions
  }
  
  # NEW: Add STS permissions for authentication
  statement {
    effect = "Allow"
    
    actions = [
      "sts:AssumeRole",
      "sts:GetCallerIdentity"
    ]
    
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_eks_access" {
  name   = "eks-access-policy"
  role   = aws_iam_role.github_ecr_push.id
  policy = data.aws_iam_policy_document.eks_access_policy.json
}

# NEW: Add Secrets Manager permissions for RDS credentials
data "aws_iam_policy_document" "secrets_access_policy" {
  statement {
    effect = "Allow"
    
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    
    resources = [
      aws_secretsmanager_secret.titanic_api.arn,
      aws_secretsmanager_secret.rds_password.arn
    ]
  }
}

resource "aws_iam_role_policy" "github_secrets_access" {
  name   = "secrets-access-policy"
  role   = aws_iam_role.github_ecr_push.id
  policy = data.aws_iam_policy_document.secrets_access_policy.json
}

# ────────────────────────────────────────────────────────────────
# Secrets Manager - Comprehensive RDS secrets
# ────────────────────────────────────────────────────────────────

resource "aws_secretsmanager_secret" "titanic_api" {
  name        = "/titanic-api/${var.environment}/rds"
  description = "All PostgreSQL connection info for Titanic API"
}

resource "aws_secretsmanager_secret_version" "titanic_api" {
  secret_id = aws_secretsmanager_secret.titanic_api.id
  secret_string = jsonencode({
    POSTGRES_USER     = "titanic_user"
    POSTGRES_PASSWORD = random_password.db_password.result
    POSTGRES_DB       = aws_db_instance.postgres.db_name
    POSTGRES_HOST     = aws_db_instance.postgres.address
    POSTGRES_PORT     = aws_db_instance.postgres.port
    SQLALCHEMY_DATABASE_URI = "postgresql://${"titanic_user"}:${random_password.db_password.result}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${aws_db_instance.postgres.db_name}"

  })
}



# ────────────────────────────────────────────────────────────────
# Outputs
# ────────────────────────────────────────────────────────────────

output "ecr_repository_url" {
  value       = aws_ecr_repository.titanic_api.repository_url
  description = "ECR repo URI for pushing images"
}

output "github_ecr_role_arn" {
  value       = aws_iam_role.github_ecr_push.arn
  description = "IAM role ARN for GitHub Actions to assume"
}

output "cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS cluster name"
}

output "cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "EKS cluster API endpoint"
}

output "rds_endpoint" {
  value       = aws_db_instance.postgres.endpoint
  description = "RDS PostgreSQL endpoint"
}

output "rds_password_secret_arn" {
  value       = aws_secretsmanager_secret.rds_password.arn
  description = "Secret ARN for RDS password"
}

output "comprehensive_secret_arn" {
  value       = aws_secretsmanager_secret.titanic_api.arn
  description = "Secret ARN containing all RDS connection info"
}

output "cluster_certificate_authority_data" {
  value       = module.eks.cluster_certificate_authority_data
  description = "Base64 encoded certificate data required to communicate with the cluster"
  sensitive   = true
}
