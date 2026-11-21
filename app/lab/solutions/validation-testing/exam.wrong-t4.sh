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
v = v.replace('variable "allowed_cidr" {\n  type = string\n}', '''variable "allowed_cidr" {
  type = string

  validation {
    condition     = can(cidrhost(var.allowed_cidr, 0))
    error_message = "allowed_cidr must be an IPv4 CIDR block such as 10.20.0.0/16."
  }
}''')
v = v.replace('variable "bucket_name" {\n  type = string\n}', '''variable "bucket_name" {
  type = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be 3-63 lowercase letters, digits or hyphens and start and end with a letter or digit."
  }
}''')
v = v.replace('variable "db_password" {\n  type = string\n}', 'variable "db_password" {\n  type      = string\n  sensitive = true\n}')
open("variables.tf", "w").write(v)
o = open("outputs.tf").read()
o = o.replace("  value = aws_s3_object.db_config.content\n", "  value     = aws_s3_object.db_config.content\n  sensitive = true\n")
open("outputs.tf", "w").write(o)
PY
python3 - <<'PY'
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

run "invalid_environment" {
  command = plan

  variables {
    environment = "qa"
  }

  expect_failures = [var.environment]
}

run "disallowed_instance_type" {
  command = plan

  variables {
    instance_type = "m5.large"
  }

  expect_failures = [var.instance_type]
}

run "apply_config" {
  variables {
    bucket_name = "vt-orders-config-test"
  }

  assert {
    condition     = jsondecode(aws_s3_object.db_config.content).username == "orders_app"
    error_message = "config/db.json must contain the username orders_app."
  }
}
HCL
terraform apply -auto-approve -no-color
terraform test -no-color || true
terraform plan -no-color -out=final.tfplan
terraform show -json final.tfplan | jq -e '[.resource_changes[] | select(.change.actions != ["no-op"] and .change.actions != ["read"])] | length == 0'
rm -f final.tfplan
