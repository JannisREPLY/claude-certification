set -euo pipefail
cat > modules/backup/versions.tf <<'HCL'
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
HCL
terraform init -upgrade -input=false -no-color
terraform plan -no-color -detailed-exitcode
cat > modules/backup/versions.tf <<'HCL'
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 5.0"
      configuration_aliases = [aws.dr]
    }
  }
}
HCL
cat > modules/backup/main.tf <<'HCL'
data "aws_caller_identity" "current" {
  provider = aws.dr
}

data "aws_vpc" "dr" {
  provider = aws.dr
  default  = true
}

resource "aws_s3_bucket" "backup" {
  provider = aws.dr
  bucket   = "nw-dr-backup-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_object" "manifest" {
  provider = aws.dr
  bucket   = aws_s3_bucket.backup.id
  key      = "manifest.json"
  content  = jsonencode({ primary_bucket = var.primary_bucket })
}

resource "aws_security_group" "app" {
  provider    = aws.dr
  name        = "nw-dr-app-sg"
  description = "Order API"
  vpc_id      = data.aws_vpc.dr.id

  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
HCL
python3 - <<'PY'
s = open("main.tf").read()
tags = '''
  default_tags {
    tags = {
      Project   = "northwind-dr"
      ManagedBy = "terraform"
    }
  }
'''
s = s.replace('provider "aws" {\n  region = "us-east-1"\n}', 'provider "aws" {\n  region = "us-east-1"\n' + tags + '}\n\nprovider "aws" {\n  alias  = "dr"\n  region = "us-west-2"\n' + tags + '}')
s = s.replace('  source = "./modules/backup"\n', '  source = "./modules/backup"\n\n  providers = {\n    aws.dr = aws.dr\n  }\n')
open("main.tf", "w").write(s)
PY
terraform apply -auto-approve -no-color
terraform plan -no-color -detailed-exitcode
