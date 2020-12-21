#!/bin/bash

DOMAIN=justinthecloud.co.uk
STACK_NAME=awsbootstrap123
REGION=us-east-1
CLI_PROFILE=awsbootstrap

EC2_INSTANCE_TYPE=t2.micro
AWS_ACCOUNT_ID=`aws sts get-caller-identity --profile awsbootstrap --query "Account" --output text`
CODEPIPELINE_BUCKET="$STACK_NAME-$REGION-codepipeline-$AWS_ACCOUNT_ID"
GH_BRANCH=master

CFN_BUCKET="$STACK_NAME-cfn-$AWS_ACCOUNT_ID"

CERT=`aws acm list-certificates --region $REGION --profile $CLI_PROFILE --output text --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn | [0]"`

# Generate a personal access token with repo and admin:repo_hook
GH_ACCESS_TOKEN=$(cat ~/.github/aws-bootstrap-access-token)
GH_OWNER=$(cat ~/.github/aws-bootstrap-owner)
GH_REPO=$(cat ~/.github/aws-bootstrap-repo)

# Deploy the CloudFormation template
# Deploy s3
echo -e "\n\n========== Deploying setup.yml =========="
aws cloudformation deploy \
    --region $REGION \
    --profile $CLI_PROFILE \
    --stack-name $STACK_NAME-setup \
    --template-file setup.yml \
    --no-fail-on-empty-changeset \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides \
    CodePipelineBucket=$CODEPIPELINE_BUCKET \
    CloudFormationBucket=$CFN_BUCKET

echo -e "\n\n========== Packaging main.yml =========="
mkdir -p ./cfn_output

PACKAGE_ERR="$(aws cloudformation package \
--region $REGION \
--profile $CLI_PROFILE \
--template main.yml \
--s3-bucket $CFN_BUCKET \
--output-template-file ./cfn_output/main.yml 2>&1)"

if ! [[ $PACKAGE_ERR =~ "Successfully packaged artifacts" ]]; then
echo "ERROR while running 'aws cloudformation package' command:"
echo $PACKAGE_ERR
exit 1
fi

echo -e "\n\n========== Deploying main.yml =========="
aws cloudformation deploy \
    --region $REGION \
    --profile $CLI_PROFILE \
    --stack-name $STACK_NAME \
    --template-file ./cfn_output/main.yml \
    --no-fail-on-empty-changeset \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides \
    Domain=$DOMAIN \
    Certificate=$CERT \
    EC2InstanceType=$EC2_INSTANCE_TYPE \
    GitHubOwner=$GH_OWNER \
    GitHubBranch=$GH_BRANCH \
    GitHubPersonalAccessToken=$GH_ACCESS_TOKEN \
    GitHubRepo=$GH_REPO \
    CodePipelineBucket=$CODEPIPELINE_BUCKET


# If deploy succeeded, show the DNS name of the created instance
if [ $? -eq 0 ]; then
aws cloudformation list-exports \
--profile awsbootstrap \
--query "Exports[?ends_with(Name,'LBEndpoint')].Value"
fi