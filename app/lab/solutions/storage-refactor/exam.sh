set -euo pipefail
rm -rf modules/platform
mkdir -p modules/storage modules/access

cat > modules/storage/main.tf <<'TF'
variable "bucket_names" {
  type = set(string)
}

variable "tags" {
  type = map(string)
}

resource "aws_s3_bucket" "this" {
  for_each = var.bucket_names
  bucket   = each.key
  tags     = var.tags
}

resource "aws_s3_object" "readme" {
  for_each = aws_s3_bucket.this
  bucket   = each.value.id
  key      = "README.txt"
  content  = "Managed by Terraform. Owner: Northwind Logistics storage team."
}

output "bucket_arns" {
  value = [for b in aws_s3_bucket.this : b.arn]
}
TF

cat > modules/access/main.tf <<'TF'
variable "bucket_arns" {
  type = list(string)
}

variable "tags" {
  type = map(string)
}

data "aws_iam_policy_document" "read" {
  statement {
    sid       = "ReadBuckets"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = flatten([for arn in var.bucket_arns : [arn, "${arn}/*"]])
  }
}

resource "aws_iam_policy" "read" {
  name   = "nw-sto-read"
  policy = data.aws_iam_policy_document.read.json
  tags   = var.tags
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "reader" {
  name               = "nw-sto-reader"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "reader" {
  role       = aws_iam_role.reader.name
  policy_arn = aws_iam_policy.read.arn
}

output "reader_role_arn" {
  value = aws_iam_role.reader.arn
}
TF

cat > main.tf <<'TF'
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "labels" {
  source = "git::file:///home/coder/git/nw-sto-tagging.git?ref=v1.2.0"
  team   = "storage"
}

module "storage" {
  source       = "./modules/storage"
  bucket_names = ["nw-sto-manifests", "nw-sto-invoices", "nw-sto-archive"]
  tags         = module.labels.tags
}

module "access" {
  source      = "./modules/access"
  bucket_arns = module.storage.bucket_arns
  tags        = module.labels.tags
}

output "reader_role_arn" {
  value = module.access.reader_role_arn
}
TF

cat > moved.tf <<'TF'
moved {
  from = module.platform.aws_s3_bucket.this[0]
  to   = module.storage.aws_s3_bucket.this["nw-sto-manifests"]
}

moved {
  from = module.platform.aws_s3_bucket.this[1]
  to   = module.storage.aws_s3_bucket.this["nw-sto-invoices"]
}

moved {
  from = module.platform.aws_s3_bucket.this[2]
  to   = module.storage.aws_s3_bucket.this["nw-sto-archive"]
}

moved {
  from = module.platform.aws_s3_object.readme[0]
  to   = module.storage.aws_s3_object.readme["nw-sto-manifests"]
}

moved {
  from = module.platform.aws_s3_object.readme[1]
  to   = module.storage.aws_s3_object.readme["nw-sto-invoices"]
}

moved {
  from = module.platform.aws_s3_object.readme[2]
  to   = module.storage.aws_s3_object.readme["nw-sto-archive"]
}

moved {
  from = module.platform.aws_iam_policy.read
  to   = module.access.aws_iam_policy.read
}

moved {
  from = module.platform.aws_iam_role.reader
  to   = module.access.aws_iam_role.reader
}

moved {
  from = module.platform.aws_iam_role_policy_attachment.reader
  to   = module.access.aws_iam_role_policy_attachment.reader
}
TF

terraform init -input=false -no-color
terraform plan -input=false -no-color -out=tfplan
terraform show -json tfplan | jq -e '[.resource_changes[] | select(.change.actions | index("delete"))] | length == 0' > /dev/null
terraform apply -auto-approve -input=false -no-color tfplan
rm -f tfplan
terraform plan -input=false -no-color -detailed-exitcode
