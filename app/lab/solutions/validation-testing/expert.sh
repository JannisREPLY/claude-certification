set -euo pipefail
python3 - <<'PY'
v = open("variables.tf").read()
v = v.replace('variable "environment" {\n  type = string\n}', '''variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "environment must be dev, stage or prod."
  }
}''')
v = v.replace('variable "trusted_cidrs" {\n  type = list(string)\n}', '''variable "trusted_cidrs" {
  type = list(string)

  validation {
    condition     = length(var.trusted_cidrs) > 0
    error_message = "trusted_cidrs needs at least one CIDR block."
  }

  validation {
    condition     = alltrue([for c in var.trusted_cidrs : can(cidrhost(c, 0))])
    error_message = "Every entry of trusted_cidrs must be an IPv4 CIDR block such as 10.20.0.0/16."
  }

  validation {
    condition     = !contains(var.trusted_cidrs, "0.0.0.0/0")
    error_message = "0.0.0.0/0 is not allowed in trusted_cidrs."
  }
}''')
v = v.replace('variable "bucket_name" {\n  type = string\n}', '''variable "bucket_name" {
  type = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be 3-63 lowercase letters, digits or hyphens and start and end with a letter or digit."
  }
}''')
v = v.replace('\nvariable "db_password" {\n  type = string\n}\n', '')
open("variables.tf", "w").write(v)
t = open("terraform.tfvars").read()
open("terraform.tfvars", "w").write("".join(l for l in t.splitlines(True) if not l.startswith("db_password")))
a = open("app.tf").read().replace("password = var.db_password", "password = random_password.db.result")
a += '''
resource "random_password" "db" {
  length  = 24
  special = false
}
'''
open("app.tf", "w").write(a)
o = open("outputs.tf").read()
o = o.replace("  value = aws_s3_object.db_config.content\n", "  value     = aws_s3_object.db_config.content\n  sensitive = true\n")
o = o.replace('  value = "postgres://${var.db_username}:${var.db_password}@db.orders.internal/orders"\n', '  value     = "postgres://${var.db_username}:${random_password.db.result}@db.orders.internal/orders"\n  sensitive = true\n')
open("outputs.tf", "w").write(o)
m = open("main.tf").read().replace('''      version = "~> 5.0"
    }
''', '''      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
''')
open("main.tf", "w").write(m)
PY
python3 - strict <<'PY'
import sys
strict = len(sys.argv) > 1
a = open("app.tf").read()
type_msg = '"Instance type ${var.instance_type} is not allowed. Use one of: ${join(", ", var.allowed_instance_types)}."' if strict else '"The instance type must be one of var.allowed_instance_types."'
ami_msg = '"Image ${self.name} is ${self.architecture}, expected x86_64."' if strict else '"The AMI must be an x86_64 image."'
a = a.replace('''    values = [var.ami_name_filter]
  }
}''', '''    values = [var.ami_name_filter]
  }

  lifecycle {
    postcondition {
      condition     = self.architecture == "x86_64"
      error_message = %s
    }
  }
}''' % ami_msg)
a = a.replace('''    Environment = var.environment
  }
}''', '''    Environment = var.environment
  }

  lifecycle {
    precondition {
      condition     = contains(var.allowed_instance_types, var.instance_type)
      error_message = %s
    }
  }
}''' % type_msg)
a += '''
check "deploy_account" {
  data "aws_caller_identity" "current" {}

  assert {
    condition     = data.aws_caller_identity.current.account_id == var.expected_account_id
    error_message = "Deploying to account ${data.aws_caller_identity.current.account_id}, expected ${var.expected_account_id}."
  }
}
'''
open("app.tf", "w").write(a)
PY
mkdir -p tests
cat > tests/report.tftest.hcl <<'HCL'
run "defaults" {
  command = plan

  assert {
    condition     = aws_instance.report.instance_type == "t3.micro"
    error_message = "The default instance type must be t3.micro."
  }
}

run "open_cidr" {
  command = plan

  variables {
    trusted_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.trusted_cidrs]
}

run "arm_ami" {
  command = plan

  variables {
    ami_name_filter = "amzn2-ami-hvm-*-arm64-gp2"
  }

  expect_failures = [data.aws_ami.report]
}

run "apply_config" {
  variables {
    bucket_name = "vt-orders-config-test"
  }

  assert {
    condition     = length(jsondecode(aws_s3_object.db_config.content).password) == 24
    error_message = "The password in config/db.json must have 24 characters."
  }
}

run "stable" {
  command = plan

  variables {
    bucket_name = "vt-orders-config-test"
  }

  assert {
    condition     = output.report_instance_id == run.apply_config.report_instance_id
    error_message = "The instance must not change between runs."
  }
}
HCL
terraform init -input=false -no-color
terraform apply -auto-approve -no-color
terraform test -no-color
terraform plan -no-color -out=final.tfplan
terraform show -json final.tfplan | jq -e '[.resource_changes[] | select(.change.actions != ["no-op"] and .change.actions != ["read"])] | length == 0'
rm -f final.tfplan
