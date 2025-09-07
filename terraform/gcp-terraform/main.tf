################################################################################################
# Setup GCP infrastructure for Workload Identity Federation (WIF) testing from AWS ECS tasks
#
# Following resources are created:
#
# 1 Workload Identity Pool
# 1 Workload Identity Pool Provider
# 1 Service Account for impersonation
# 1 IAM Policy Binding for the Service Account
################################################################################################

resource "random_id" "workload_identity_pool_id_suffix" {
  byte_length = 4
}

##############################
## Enable APIs on GCP Project
##############################

# Enable IAM Credentials API to allow for Service Account impersonation
resource "google_project_service" "iam_credentials_api" {
  project = var.project_name
  service = "iamcredentials.googleapis.com"
}

# Enable Cloud Resource Manager API to allow Service Account to list projects
resource "google_project_service" "cloud_resource_manager_api" {
  project = var.project_name
  service = "cloudresourcemanager.googleapis.com"
}

##################################################
## GCP Workload Identity Federation Configuration 
##################################################

resource "google_iam_workload_identity_pool" "aws-ecs-task-pool" {
  project                   = var.project_name
  workload_identity_pool_id = "wif-pool-for-aws-ecs-${random_id.workload_identity_pool_id_suffix.hex}"
  display_name              = "AWS ECS Task Federation Pool"
  description               = "Workload Identity Pool for AWS ECS Task federation"
}

resource "google_iam_workload_identity_pool_provider" "provider" {
  project                            = var.project_name
  workload_identity_pool_id          = google_iam_workload_identity_pool.aws-ecs-task-pool.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = "AWS Provider"
  description                        = "AWS identity pool provider for ECS tasks"

  aws {
    account_id = var.aws_account_id
  }

  attribute_mapping = {
    "google.subject"     = "assertion.arn",
    ## Add AWS Role attribute mapping to restrict access to a single AWS role
    "attribute.aws_role" = "assertion.arn.extract('{account_arn}assumed-role') + 'assumed-role/' + assertion.arn.extract('assumed-role/{role_name}/')"
  }
}

##################################################
## Service Account Configuration for Impersonation
##################################################

resource "google_service_account" "gcp_service_account" {
  project      = var.project_name
  account_id   = var.service_account_id
  display_name = "WIF SA - AWS ECS Task"
  description  = "Service Account used for impersonation by AWS ECS Task for WIF Access"
}

resource "google_service_account_iam_member" "wif_impersonation" {
  service_account_id = google_service_account.gcp_service_account.name
  role               = "roles/iam.workloadIdentityUser"
  ## Restricting access to specific AWS Role (ECS Task Role) through attribute mapping
  member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.aws-ecs-task-pool.name}/attribute.aws_role/arn:aws:sts::${var.aws_account_id}:assumed-role/gcp-wif-ecs-task-role"

  depends_on = [
    google_iam_workload_identity_pool.aws-ecs-task-pool,
    google_iam_workload_identity_pool_provider.provider
    ]
}

resource "google_project_iam_member" "role_binding" {
  project = var.project_name
  ## Granting Viewer Role to the Service Account to List Resources
  role   = var.sa_role
  member = "serviceAccount:${google_service_account.gcp_service_account.email}"
}