# tf-aws-infra

## Prerequisites
1. Terraform installed
2. GitHub CLI or access to GitHub repository settings
3. AWS account and credentials configured

## Setup
    1. Clone the Repository:
        git clone https://github.com/{yourusername}/{yourrepository}.git
        cd yourrepository

    2. Configure AWS Credentials:
        Ensure your AWS credentials are set up correctly in ~/.aws/credentials or use environment variables.

## Initialize Terraform:
    terraform init

## GitHub Actions
    This project uses GitHub Actions to automate the CI process according to the given "terraform-ci.yml" file.
    Terraform Format Check: Ensures all Terraform files are properly formatted.
    Terraform Validate: Validates the syntax of Terraform configuration files.

## Branch Protection
    The main branch is protected with required status checks to ensure code quality before merging.