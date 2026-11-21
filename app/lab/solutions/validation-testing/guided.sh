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
v = v.replace('variable "db_password" {\n  type = string\n}', 'variable "db_password" {\n  type      = string\n  sensitive = true\n}')
open("variables.tf", "w").write(v)
o = open("outputs.tf").read()
o = o.replace("  value = aws_s3_object.db_config.content\n", "  value     = aws_s3_object.db_config.content\n  sensitive = true\n")
open("outputs.tf", "w").write(o)
PY
mkdir -p tests
cat > tests/validation.tftest.hcl <<'HCL'
run "valid" {
  command = plan

  assert {
    condition     = aws_instance.report.instance_type == "t3.micro"
    error_message = "The default instance type must be t3.micro."
  }
}

run "invalid_cidr" {
  command = plan

  variables {
    allowed_cidr = "10.20.0.300/16"
  }

  expect_failures = [var.allowed_cidr]
}
HCL
terraform apply -auto-approve -no-color
terraform test -no-color
terraform plan -no-color -out=final.tfplan
terraform show -json final.tfplan | jq -e '[.resource_changes[] | select(.change.actions != ["no-op"] and .change.actions != ["read"])] | length == 0'
rm -f final.tfplan
