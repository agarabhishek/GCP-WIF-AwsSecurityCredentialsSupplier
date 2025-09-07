# google-auth-python-AwsSecurityCredentialsSupplier

<img src=https://agarabhishek.com/images/gcp_wif_aws_ecs_cover_large.jpg alt="GCP WIF AWS ECS Cover Image">

Implements a Python Custom AWS Security Credential Supplier for performing GCP Workload Identity Federation (WIF) via AWS ECS tasks

[GCP authentication libraries](https://cloud.google.com/docs/authentication/client-libraries) do not support WIF natively for AWS ECS tasks. To perform WIF from ECS, a custom AWS credential supplier is needed. Python implementation of [`AwsSecurityCredentialsSupplier`](https://github.com/googleapis/google-auth-library-java?tab=readme-ov-file#using-a-custom-supplier-with-aws) class is provided which can be used with the `google-auth` [Python library](https://googleapis.dev/python/google-auth/latest/index.html). 

For more details, see the full post here: [GCP Workload Identity Federation with AWS ECS Tasks](https://agarabhishek.com/posts/gcp-workload-identity-federation-with-aws-ecs-tasks/).

## Implementation

The [custom AWS credential supplier class:](aws_security_credentials_supplier.py) `CustomAwsSecurityCredentialsSupplier` extends the base class: `AwsSecurityCredentialsSupplier` and implements two functions: 
- `get_aws_security_credentials` and
- `get_aws_region` 

that tell `google-auth` library how to obtain AWS security credentials and the AWS region in the context of an ECS task.

## Workload Identity Federation Test

In order to test the WIF flow from ECS tasks, [gcp_wif_test](tests/gcp_wif_test.py) leverages this custom AWS credential supplier and calls the [GCP projects list API](https://cloud.google.com/resource-manager/reference/rest/v1/projects/get): `https://cloudresourcemanager.googleapis.com/v1/projects`.

## Automated Testing

For facilitating testing, a container image is already deployed at Docker Hub: [agarabhishek/gcp-wif-from-aws-ecs](https://hub.docker.com/r/agarabhishek/gcp-wif-from-aws-ecs). The [terraform](terraform) folder contains the necessary Terraform scripts to set up the required infrastructure for testing. A handy bash script: [run_test.sh](/terraform/run_test.sh) is provided to automatically apply all the terraform steps. [clean.sh](/terraform/clean.sh) is also provided to tear down the infrastructure.

### Requirements

- GCP Project
- AWS Account

Make sure Terraform can authenticate to both GCP and AWS

### Steps

```bash
# Run end to end test
cd terraform
## Create terraform.tfvars files for aws-terraform and gcp-terraform (example file provided)
## For GCP, fill in the GCP `project_name` and `aws_account_id` values
## For AWS, fill in the AWS `region` 
./run_test.sh

# Run cleanup
cd terraform && ./clean.sh
```

## Behind the Scenes

Resources are deployed in your GCP and AWS environment and an ECS task is executed which authenticates to your GCP and lists your projects.

For GCP, following resources are created:
- Workload Identity Pool
- Workload Identity Pool Provider
- Service Account ([for performing the service account impersonation WIF flow](https://agarabhishek.com/posts/gcp-workload-identity-federation-with-aws-ecs-tasks/#tldr-please---how-does-gcp-workload-identity-federation-wif-work))
- IAM Policy Binding for the Service Account

In your GCP project, the following APIs are enabled:
- `iamcredentials.googleapis.com` (to allow for Service Account impersonation)
- `cloudresourcemanager.googleapis.com` (to allow Service Account to list projects)

and the created Service Account is provided `viewer` role by default.

For AWS, the following resources are created:
- ECS Cluster & an ECS Task
- S3 Bucket to hold Workload Identity Federation configuration credentials file
- CloudWatch Log Group for logging ECS task output
- 2 IAM Roles - ECS task execution role and ECS task role
- VPC, subnet and a security group for the ECS task

The ECS task definition is configured to fetch the Docker Hub image. If you want to deploy your own image, you can use the provided [Dockerfile](terraform/aws-terraform/Dockerfile).

## Result

The last step in the test is looking at ECS logs to see the GCP projects API response. A successful response would look something like this:

```bash
gcp_wif_test [INFO ]  Reading Workload Identity Federation credential configuration from S3
gcp_wif_test [INFO ]  GCP WIF Credentials Object Created
gcp_wif_test [INFO ]  Making an authenticated request to GCP API to List Projects
custom_aws_credentials_supplier [INFO ]  Fetched AWS Region
custom_aws_credentials_supplier [INFO ]  AWS Credentials obtained successfully
gcp_wif_test [INFO ]  Response of GCP Projects List API call:
{'projects': [{'projectNumber': 'XXXXXXXX', 'projectId': 'XXXXXX', 'name': 'XXXXXXXXXX'}, 'createTime': 'XXXXXXX'}]}
```

### Demo

[![Demo Video](https://img.youtube.com/vi/UaTXLLufaNQ/0.jpg)](https://www.youtube.com/watch?v=UaTXLLufaNQ)

## Manual Testing

### GCP

1. Navigate to the [terraform/gcp-terraform](terraform/gcp-terraform/) directory
2. Create a `terraform.tfvars` file from the example [terraform.tfvars.example](terraform/gcp-terraform/terraform.tfvars.example) file and provide values for `project_name` and `aws_account_id`
3. Run `terraform init`
4. Run `terraform plan`
5. Run `terraform apply`
6. Run the command `terraform output -json client_library_config | jq -r . > ../resources/client_config.json` to store the client library configuration

### AWS

1. Navigate to the [terraform/aws-terraform](terraform/aws-terraform/) directory
2. Create a `terraform.tfvars` file from the example [terraform.tfvars.example](terraform/aws-terraform/terraform.tfvars.example) file and provide a value for `aws_region`
3. Run `terraform init`
4. Run `terraform plan`
5. Run `terraform apply -auto-approve`
6. To monitor the logs, run the command `aws logs tail /ecs/gcp-wif-task --follow --region us-east-2`


> Note: The provided AWS terraform automatically launches an ECS task for the test. If you want to repeat the test by running more ECS tasks, you can use the following AWS CLI command. The values for `subnets` and `securityGroups` should be taken from the terraform output.

```bash
aws ecs run-task \
   --cluster gcp-wif-cluster \
   --task-definition gcp-wif-task \
   --launch-type FARGATE \
   --network-configuration "awsvpcConfiguration={subnets=[XXXXXX],securityGroups=[XXXXXXXX],assignPublicIp=ENABLED}" \
   --region us-east-2 \
   --enable-ecs-managed-tags \
   --propagate-tags TASK_DEFINITION
```