locals {
  tags = {
    Team    = "storage"
    Company = "Northwind Logistics"
  }
}

resource "aws_s3_bucket" "this" {
  count  = length(var.bucket_names)
  bucket = var.bucket_names[count.index]
  tags   = local.tags
}

resource "aws_s3_object" "readme" {
  count   = length(var.bucket_names)
  bucket  = aws_s3_bucket.this[count.index].id
  key     = "README.txt"
  content = "Managed by Terraform. Owner: Northwind Logistics storage team."
}

data "aws_iam_policy_document" "read" {
  statement {
    sid       = "ReadBuckets"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = flatten([for b in aws_s3_bucket.this : [b.arn, "${b.arn}/*"]])
  }
}

resource "aws_iam_policy" "read" {
  name   = "nw-sto-read"
  policy = data.aws_iam_policy_document.read.json
  tags   = local.tags
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
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "reader" {
  role       = aws_iam_role.reader.name
  policy_arn = aws_iam_policy.read.arn
}
