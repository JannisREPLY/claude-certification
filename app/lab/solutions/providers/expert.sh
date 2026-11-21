set -euo pipefail
cat > modules/reports/main.tf <<'HCL'
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 4.67"
      configuration_aliases = [aws.west]
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
  }
}

variable "name" {
  type = string
}

resource "aws_s3_bucket" "primary" {
  bucket = "${var.name}-east"

  tags = {
    Team = "reports"
  }
}

resource "aws_s3_bucket" "replica" {
  provider = aws.west
  bucket   = "${var.name}-west"

  tags = {
    Team = "reports"
  }
}

output "primary_bucket" {
  value = aws_s3_bucket.primary.bucket
}

output "replica_bucket" {
  value = aws_s3_bucket.replica.bucket
}
HCL
python3 - <<'PY'
s = open("main.tf").read()
s = s.replace('version = "3.1.0"', 'version = "~> 3.6.0"')
tags = '''

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = "reports"
    }
  }
}'''
s = s.replace('''provider "aws" {
  region = "us-east-1"
}''', '''provider "aws" {
  region = "us-east-1"''' + tags + '''

provider "aws" {
  alias  = "west"
  region = "us-west-2"''' + tags + '''

data "aws_vpc" "default_west" {
  provider = aws.west
  default  = true
}

resource "aws_security_group" "web_west" {
  provider    = aws.west
  name        = "web-west-${random_integer.build.result}"
  description = "Web servers"
  vpc_id      = data.aws_vpc.default_west.id
}''')
s = s.replace('''  source = "./modules/reports"
''', '''  source = "./modules/reports"
  providers = {
    aws      = aws
    aws.west = aws.west
  }
''')
open("main.tf", "w").write(s)
PY
terraform init -upgrade -input=false -no-color
terraform apply -auto-approve -input=false -no-color
terraform plan -input=false -no-color -detailed-exitcode
