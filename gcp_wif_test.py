import os
import boto3
from google.auth import aws
from google.auth import exceptions
from aws_security_credentials_supplier import CustomAwsSecurityCredentialsSupplier
import logging
import json
from google.auth.transport.requests import AuthorizedSession

logFormatter = logging.Formatter("%(name)s [%(levelname)-5.5s]  %(message)s")
logger = logging.getLogger("gcp_wif_test")
logger.setLevel(logging.INFO)

consoleHandler = logging.StreamHandler()
consoleHandler.setFormatter(logFormatter)
logger.addHandler(consoleHandler)

def read_workload_identity_federation_config(s3_bucket_name: str, s3_key: str) -> dict:
    """
    Read the Workload Identity Federation configuration from S3.
    """
    s3 = boto3.client('s3')
    response = s3.get_object(Bucket=s3_bucket_name, Key=s3_key)
    logger.info("Reading Workload Identity Federation credential configuration from S3")
    workload_identity_federation_config = json.loads(response['Body'].read().decode('utf-8'))
    return workload_identity_federation_config


def setup_gcp_wif_credentials(supplier, workload_identity_federation_config) -> aws.Credentials:
    """
    Setup the custom credentials object for GCP Workload Identity Federation
    """
    credentials = aws.Credentials(
        audience=workload_identity_federation_config["audience"],
        subject_token_type=workload_identity_federation_config["subject_token_type"],
        aws_security_credentials_supplier=supplier,
        service_account_impersonation_url=workload_identity_federation_config[
            "service_account_impersonation_url"
        ],
        scopes=["https://www.googleapis.com/auth/cloud-platform"],
    )
    return credentials

def main() -> None:
    """
    Main function to execute the GCP WIF authentication flow
    """
    try:
        # Read the Workload Identity Federation configuration file from S3
        s3_bucket_name = os.environ.get("S3_BUCKET_NAME")
        if not s3_bucket_name:
            raise ValueError("S3_BUCKET_NAME environment variable not set")
        s3_key = "client_config.json"
        workload_identity_federation_config = read_workload_identity_federation_config(s3_bucket_name, s3_key)

        # Setup GCP WIF credentials
        supplier = CustomAwsSecurityCredentialsSupplier()
        wif_credentials = setup_gcp_wif_credentials(supplier, workload_identity_federation_config)
        logger.info("GCP WIF Credentials Object Created")

        ## Test WIF Access
        logger.info("Making an authenticated request to GCP API to List Projects")
        authed_session = AuthorizedSession(wif_credentials)
        response = authed_session.get(
            "https://cloudresourcemanager.googleapis.com/v1/projects"
        )
        logger.info("Response of GCP Projects List API call:")
        print(response.json())

    except Exception as e:
        logger.error("Error in GCP WIF: %s", e)
        raise e


if __name__ == "__main__":
    main()
