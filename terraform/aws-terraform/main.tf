##################################################################################################
# Setup AWS infrastructure for performing GCP Workload Identity Federation (WIF) testing
# Following resources are created:
#
# 1 VPC with internet access
#  - Contains 1 Subnet and 1 Security Group (SG)
#    ECS tasks are deployed in this subnet and use this SG
# 1 S3 bucket to store GCP WIF credential configuration file
# 1 ECS Cluster
# 1 ECS Task Definition, defining:
#   - Tasks would run on FARGATE
#   - Environment variable S3_BUCKET_NAME which stores the GCP WIF credential configuration file
# 2 IAM Roles: 1 for ECS Task Execution and 1 for ECS Task
#  - Task Execution Role allows the ECS tasks to pull images from ECR
#  - Task Role allows the ECS tasks to access the S3 bucket
# 1 CloudWatch Log Group for logging ECS task output
#
# Finally, an ECS task is launched which performs the GCP WIF authentication
# and calls a GCP API to test successful authentication
##################################################################################################

########################
## Network Configuration
########################

resource "aws_vpc" "ecs_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Internet Gateway to reach GCP
resource "aws_internet_gateway" "vpc_internet_gateway" {
  vpc_id = aws_vpc.ecs_vpc.id
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.ecs_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpc_internet_gateway.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.ecs.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_subnet" "ecs" {
  vpc_id     = aws_vpc.ecs_vpc.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_security_group" "sg" {
  vpc_id = aws_vpc.ecs_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

##########################
## S3 Bucket Configuration
##########################

# S3 bucket is used to store credentials configuration file generated from GCP

resource "aws_s3_bucket" "gcp_wif_bucket" {
  bucket = "gcp-wif-aws-ecs-bucket-${uuid()}"
}

resource "aws_s3_object" "client_config_json" {
  bucket = aws_s3_bucket.gcp_wif_bucket.id
  key    = "client_config.json"
  source = "${path.module}/../resources/client_config.json"
  etag   = filemd5("${path.module}/../resources/client_config.json")
}

resource "aws_s3_bucket_ownership_controls" "gcp_wif_bucket_ownership_controls" {
  bucket = aws_s3_bucket.gcp_wif_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "gcp_wif_bucket_public_access_block" {
  bucket = aws_s3_bucket.gcp_wif_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_acl" "gcp_wif_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.gcp_wif_bucket_ownership_controls]

  bucket = aws_s3_bucket.gcp_wif_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "gcp_wif_bucket_versioning" {
  bucket = aws_s3_bucket.gcp_wif_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "gcp_wif_bucket_encryption" {
  bucket = aws_s3_bucket.gcp_wif_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


####################
## ECS Configuration
####################

resource "aws_ecs_cluster" "gcp_wif_cluster" {
  name = var.ecs_cluster_name
}

resource "docker_image" "gcp-wif-from-aws-ecs" {
  name = var.ecs_task_container_image
}

resource "aws_ecs_task_definition" "gcp_wif_task" {
  family                   = var.ecs_task_family
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name      = var.ecs_container_name
      image     = docker_image.gcp-wif-from-aws-ecs.name
      cpu       = tonumber(var.ecs_task_cpu)
      memory    = tonumber(var.ecs_task_memory)
      essential = true
      environment = [
        {
          name  = "S3_BUCKET_NAME"
          value = aws_s3_bucket.gcp_wif_bucket.id
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  depends_on = [
    aws_s3_bucket.gcp_wif_bucket
  ]
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name = var.aws_cloudwatch_log_group_name
}

##############################
## ECS IAM Roles Configuration
##############################

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "gcp-wif-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task_role" {
  name = "gcp-wif-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS task role fetches GCP WIF credentials configuration file from S3 Bucket
resource "aws_iam_role_policy_attachment" "ecs_task_role_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.s3_read_access_policy.arn
}

resource "aws_iam_policy" "s3_read_access_policy" {
  name        = "gcp-wif-ecs-task-s3-read-access-policy"
  description = "IAM policy for S3 read access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.gcp_wif_bucket.arn,
          "${aws_s3_bucket.gcp_wif_bucket.arn}/*"
        ]
      }
    ]
  })

  depends_on = [
    aws_s3_bucket.gcp_wif_bucket,
    aws_s3_object.client_config_json
  ]

}

######################
## Run ECS Task
######################

resource "null_resource" "run_ecs_task" {
  # This ensures the task runs after the infrastructure is in place
  depends_on = [
    aws_ecs_cluster.gcp_wif_cluster,
    aws_ecs_task_definition.gcp_wif_task,
    aws_iam_role_policy_attachment.ecs_task_execution_role_policy,
    aws_iam_role_policy_attachment.ecs_task_role_policy,
    aws_route_table_association.a, # Ensures networking is ready
  ]

  # A trigger to re-run the task if the task definition changes.
  triggers = {
    task_definition_arn = aws_ecs_task_definition.gcp_wif_task.arn
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws ecs run-task \
        --cluster ${aws_ecs_cluster.gcp_wif_cluster.name} \
        --task-definition ${aws_ecs_task_definition.gcp_wif_task.arn} \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[${aws_subnet.ecs.id}],securityGroups=[${aws_security_group.sg.id}],assignPublicIp=ENABLED}" \
        --region ${var.aws_region} \
        --enable-ecs-managed-tags \
        --propagate-tags TASK_DEFINITION
    EOT
  }
}