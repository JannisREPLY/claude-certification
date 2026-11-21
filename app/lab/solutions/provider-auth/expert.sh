set -euo pipefail
old=$(awk '/^\[/ { s = ($0 == "[ci]") } s && $1 == "aws_access_key_id" { print $3 }' /home/coder/secrets/credentials)
key=$(aws iam create-access-key --user-name terraform-ci --query AccessKey --output json)
aws iam delete-access-key --user-name terraform-ci --access-key-id "$old"
printf '[ci]\naws_access_key_id = %s\naws_secret_access_key = %s\n' "$(jq -r .AccessKeyId <<< "$key")" "$(jq -r .SecretAccessKey <<< "$key")" > /home/coder/secrets/credentials
rm -f terraform.tfvars
cat > modules/audit/main.tf <<'HCL'
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "team" {
  type = string
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "auditor" {
  name = "${var.team}-auditor"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "sts:AssumeRole"
    }]
  })
}

output "deployer" {
  value = data.aws_caller_identity.current.arn
}
HCL
cat > main.tf <<'HCL'
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                   = "us-east-1"
  profile                  = "ci"
  shared_credentials_files = ["/home/coder/secrets/credentials"]
  shared_config_files      = ["/home/coder/secrets/config"]

  assume_role {
    role_arn     = "arn:aws:iam::123456789012:role/terraform-deploy"
    session_name = "terraform"
  }
}

provider "aws" {
  alias                    = "audit"
  region                   = "us-east-1"
  profile                  = "ci"
  shared_credentials_files = ["/home/coder/secrets/credentials"]
  shared_config_files      = ["/home/coder/secrets/config"]

  assume_role {
    role_arn     = "arn:aws:iam::123456789012:role/terraform-audit"
    session_name = "terraform-audit"
  }
}

data "aws_caller_identity" "current" {}

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

module "audit" {
  source   = "./modules/audit"
  for_each = toset(["platform", "data"])
  providers = {
    aws = aws.audit
  }

  team = each.key
}

output "caller_arn" {
  value = data.aws_caller_identity.current.arn
}

output "issuer_arn" {
  value = data.aws_iam_session_context.current.issuer_arn
}

output "deployers" {
  value = { for team, m in module.audit : team => m.deployer }
}
HCL
terraform init -input=false -no-color
terraform apply -auto-approve -input=false -no-color
terraform providers -no-color > providers.txt
terraform version -no-color > version.txt
ls -d .terraform/providers/registry.terraform.io/hashicorp/aws/*/*/terraform-provider-aws_* > plugin-path.txt
terraform plan -input=false -no-color -detailed-exitcode
