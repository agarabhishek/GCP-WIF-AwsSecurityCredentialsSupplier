import google.auth
from google.auth import aws
import boto3
import logging
import os

logFormatter = logging.Formatter("%(name)s [%(levelname)-5.5s]  %(message)s")
logger = logging.getLogger("custom_aws_credentials_supplier")
logger.setLevel(logging.INFO)

consoleHandler = logging.StreamHandler()
consoleHandler.setFormatter(logFormatter)
logger.addHandler(consoleHandler)

class CustomAwsSecurityCredentialsSupplier(aws.AwsSecurityCredentialsSupplier):
    '''
    Custom AWS Security Credentials Supplier for fetching AWS credentials and region
    '''

    def get_aws_security_credentials(self, context, request) -> aws.AwsSecurityCredentials:
        '''
        Fetch AWS security credentials from Boto3 get_credentials endpoint
        '''
        try:
            # AWS SDKs automatically fetch credentials using ECS Metadata endpoint
            # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/security-iam-roles.html#security-iam-task-role
            # https://boto3.amazonaws.com/v1/documentation/api/latest/reference/core/session.html#boto3.session.Session.get_credentials
            session = boto3.Session()
            credentials = session.get_credentials()
            logger.info("AWS Credentials obtained successfully")
            return aws.AwsSecurityCredentials(credentials.access_key, credentials.secret_key, credentials.token)
        except Exception as e:
            logger.error("Error fetching AWS credentials: %s", e)
            raise google.auth.exceptions.RefreshError(e, retryable=True)

    def get_aws_region(self, context, request) -> str:
        '''
        Fetch AWS region from ECS environment variables
        '''
        try:
            # ECS tasks have AWS_REGION environment variable set
            # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-environment-variables.html
            if os.environ.get("AWS_REGION"):
                logger.info("Fetched AWS Region")
                return os.environ.get("AWS_REGION")
            else:
                raise ValueError("AWS_REGION environment variable is not set")
        except Exception as e:
            logger.error("Error fetching AWS region: %s", e)
            raise google.auth.exceptions.RefreshError(e, retryable=True)