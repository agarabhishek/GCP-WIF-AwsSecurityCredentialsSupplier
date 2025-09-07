#!/bin/bash
set -e

GCP_TERRAFORM_DIR="gcp-terraform"
AWS_TERRAFORM_DIR="aws-terraform"

# Message Formatting
display_message() {
  echo -e "\n###### $1 ######"
}

# GCP Deployment
setup_gcp_infrastructure() {
  display_message "Starting GCP deployment"
  pushd "${GCP_TERRAFORM_DIR}" > /dev/null
  echo -e "Running Terraform Init"
  terraform init > /dev/null
  echo -e "Running Terraform Plan"
  terraform plan > /dev/null
  echo -e "Running Terraform Apply"
  terraform apply --auto-approve
  mkdir -p ../resources # Ensure resources directory exists
  terraform output -json client_library_config | jq -r . > ../resources/client_config.json
  display_message "GCP deployment complete"
  popd > /dev/null
}

# AWS deployment
setup_aws_infrastructure() {
  display_message "Starting AWS deployment"
  pushd "${AWS_TERRAFORM_DIR}" > /dev/null
  echo -e "Running Terraform Init"
  terraform init > /dev/null
  echo -e "Running Terraform Plan"
  terraform plan > /dev/null
  echo -e "Running Terraform Apply"
  terraform apply --auto-approve
  display_message "AWS deployment complete"
  popd > /dev/null
}

# Monitor AWS ECS logs
monitor_aws_ecs_logs() {
  display_message "Monitor AWS ECS Task logs"
  aws logs tail /ecs/gcp-wif-task --follow --region us-east-2
}

setup_gcp_infrastructure
sleep 5 # Gives time for GCP resources to be provisioned fully
setup_aws_infrastructure
monitor_aws_ecs_logs