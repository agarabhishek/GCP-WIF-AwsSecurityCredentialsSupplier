variable "project_name" {
  description = "GCP project ID"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "provider_id" {
  description = "ID of the Workload Identity Pool Provider"
  type        = string
  default     = "aws-provider"
}

variable "service_account_id" {
  description = "ID of the Service Account to be impersonated"
  type        = string
  default     = "sa-for-aws-ecs-wif"
}

variable "sa_role" {
  description = "Role attached the Service Account to be impersonated"
  type        = string
  default     = "roles/viewer"
}