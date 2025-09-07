variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
  default     = "gcp-wif-cluster"
}

variable "ecs_task_family" {
  description = "Family of the ECS task definition"
  type        = string
  default     = "gcp-wif-task"
}

variable "ecs_container_name" {
  description = "Name of the ECS container"
  type        = string
  default     = "gcp-wif-ecs-container"
}

variable "ecs_task_container_image" {
  description = "Container image for the ECS task"
  type        = string
  default     = "agarabhishek/gcp-wif-from-aws-ecs:latest"
}

variable "ecs_task_cpu" {
  description = "CPU units for the ECS task"
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "Memory for the ECS task"
  type        = number
  default     = 512
}

variable "aws_cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  type        = string
  default     = "/ecs/gcp-wif-task"
}