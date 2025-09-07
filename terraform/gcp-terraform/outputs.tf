output "workload_identity_pool_name" {
  value = google_iam_workload_identity_pool.aws-ecs-task-pool.name
}

output "workload_identity_pool_provider_name" {
  value = google_iam_workload_identity_pool_provider.provider.name
}

output "service_account_email" {
  value = google_service_account.gcp_service_account.email
}

output "client_library_config" {
  value = jsonencode({
    universe_domain                   = "googleapis.com",
    type                              = "external_account",
    audience                          = "//iam.googleapis.com/${google_iam_workload_identity_pool_provider.provider.name}",
    subject_token_type                = "urn:ietf:params:aws:token-type:aws4_request",
    service_account_impersonation_url = "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${google_service_account.gcp_service_account.email}:generateAccessToken",
    token_url                         = "https://sts.googleapis.com/v1/token",
    credential_source = {
      environment_id                 = "aws1",
      region_url                     = "http://169.254.169.254/latest/meta-data/placement/availability-zone",
      url                            = "http://169.254.169.254/latest/meta-data/iam/security-credentials",
      regional_cred_verification_url = "https://sts.{region}.amazonaws.com?Action=GetCallerIdentity&Version=2011-06-15"
    }
  })
}