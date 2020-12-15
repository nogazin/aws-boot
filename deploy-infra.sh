#!/bin/bash

STACK_NAME=awsbootstrap1
REGION=us-east-1
CLI_PROFILE=awsbootstrap

EC2_INSTANCE_TYPE=t2.micro
AWS_ACCOUNT_ID=`aws sts get-caller-identity --profile awsbootstrap --query "Account" --output text`
CODEPIPELINE_BUCKET="$STACK_NAME-$REGION-codepipeline-$AWS_ACCOUNT_ID"
GH_BRANCH=master

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
    --stack-name $STACK_NAME \
    --template-file setup.yml \
    --no-fail-on-empty-changeset \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides CodePipelineBucket=$CODEPIPELINE_BUCKET

echo -e "\n\n========== Deploying main.yml =========="
aws cloudformation deploy \
    --region $REGION \
    --profile $CLI_PROFILE \
    --stack-name $STACK_NAME \
    --template-file main.yml \
    --no-fail-on-empty-changeset \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides \
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
--query "Exports[?starts_with(Name,'InstanceEndpoint')].Value"
fi