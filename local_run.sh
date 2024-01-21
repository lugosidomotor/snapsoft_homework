#!/bin/bash
set -e

# Function to check if a command exists
command_exists() {
  type "$1" &> /dev/null
}

# Check for AWS CLI
if ! command_exists aws; then
  echo "Installing AWS CLI..."
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install
fi

# Check for Terraform
if ! command_exists terraform; then
  echo "Installing Terraform..."
  sudo apt-get update && sudo apt-get install -y software-properties-common
  curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
  sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
  sudo apt-get update && sudo apt-get install terraform
fi

# Check for Git
if ! command_exists git; then
  echo "Installing Git..."
  sudo apt-get update && sudo apt-get install -y git
fi

# Check for NPM
if ! command_exists npm; then
  echo "Installing npm..."
  sudo apt-get update && sudo apt-get install -y npm
fi

# Check for jq
if ! command_exists jq; then
  echo "Installing jq..."
  sudo apt-get update && sudo apt-get install -y jq
fi

# Check for curl
if ! command_exists curl; then
  echo "Installing curl..."
  sudo apt-get update && sudo apt-get install -y curl
fi

# Load environment variables from local_run_envs file
if [ -f "local_run_envs" ]; then
  export $(cat local_run_envs | xargs)
  export company=$(whoami)
else
  echo "local_run_envs file not found"
  exit 1
fi

# Ensure required variables are set
: "${access_key_id:?Need to set access-key-id in local_run_envs}"
: "${secret_access_key:?Need to set secret-access-key in local_run_envs}"
: "${terraform_action:?Need to set terraform-action in local_run_envs (apply or destroy)}"
: "${aws_region:=us-west-2}"  # Default to us-west-2 if not set
: "${environment:=dev}"

# Install Node.js Dependencies (assuming Node.js is already installed)
npm install pg

# Configure AWS Credentials
export AWS_ACCESS_KEY_ID=$access_key_id
export AWS_SECRET_ACCESS_KEY=$secret_access_key
export AWS_DEFAULT_REGION=$aws_region

# Check if S3 State Bucket exists
bucket_name="${company}-terraform-state-${environment}"
region="${aws_region}"

if aws s3api head-bucket --bucket "$bucket_name" --region "$region" 2>/dev/null; then
  echo "Bucket already exists: $bucket_name"
else
  echo "Bucket does not exist. Creating $bucket_name..."
  aws s3api create-bucket --bucket "$bucket_name" --region "$region" --create-bucket-configuration LocationConstraint="$region"
  echo "Bucket created: $bucket_name"
fi

# Check if S3 Lambda Code Bucket exists
bucket_name="${company}-${environment}-lambda-code-bucket"
region="${aws_region}"

if aws s3api head-bucket --bucket "$bucket_name" --region "$region" 2>/dev/null; then
  echo "Bucket already exists: $bucket_name"
else
  echo "Bucket does not exist. Creating $bucket_name..."
  aws s3api create-bucket --bucket "$bucket_name" --region "$region" --create-bucket-configuration LocationConstraint="$region"
  echo "Bucket created: $bucket_name"
fi

# Terraform Initialization
terraform init -backend-config="region=$aws_region" -backend-config="key=$company-terraform-state-$environment" -backend-config="bucket=$company-terraform-state-$environment"

# Terraform Formatting
terraform fmt

# Terraform Validation
terraform validate

# Terraform Apply or Destroy
terraform $terraform_action -var="aws_region=$aws_region" -var="company=$company" -var="environment=$environment" -auto-approve

# Outputs
if [ "$terraform_action" = "apply" ]; then
  API_ENDPOINT=$(terraform output -raw api_gateway_endpoint)
  API_KEY=$(terraform output -raw api_key)
  export API_ENDPOINT API_KEY
fi

# Test API Endpoint
if [ "$terraform_action" = "apply" ]; then
  curl_command="curl -X POST -H 'Content-Type: application/json' -H 'x-api-key: $API_KEY' -d '{\"message\": \"Example message\", \"target\": \"example.com\"}' $API_ENDPOINT"
  echo "Executing: $curl_command"
  eval "$curl_command"
fi