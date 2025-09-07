#!/bin/bash
set -e

AWS_TERRAFORM_DIR="aws-terraform"
GCP_TERRAFORM_DIR="gcp-terraform"
RESOURCES_DIR="resources"

# Message Formatting
display_message() {
  echo -e "###### $1 ######"
}

# Clean up GCP resources
cleanup_gcp_resources() {
  display_message "Starting GCP resource destruction"
  pushd "${GCP_TERRAFORM_DIR}" > /dev/null
  terraform destroy -auto-approve > /dev/null # Suppress verbose output
  popd > /dev/null
  display_message "GCP resource destruction complete"
}

# Clean up AWS resources
cleanup_aws_resources() {
  display_message "Starting AWS resource destruction"
  pushd "${AWS_TERRAFORM_DIR}" > /dev/null
  terraform destroy -auto-approve > /dev/null # Suppress verbose output
  popd > /dev/null
  display_message "AWS resource destruction complete"
}

# Clean up WIF credential configuration file
cleanup_local_files() {
  display_message "Cleaning up local files"
  rm -f "${RESOURCES_DIR}/client_config.json"
}

cleanup_aws_resources
cleanup_gcp_resources
cleanup_local_files
display_message "Cleanup complete"
