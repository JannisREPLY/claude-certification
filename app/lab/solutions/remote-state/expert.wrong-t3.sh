set -euo pipefail
cat > backend.hcl <<'HCL'
bucket         = "tfstate-lab"
region         = "us-east-1"
dynamodb_table = "tf-locks"
encrypt        = true
HCL
cd platform
cat > backend.tf <<'HCL'
terraform {
  backend "s3" {
    key = "platform/terraform.tfstate"
  }
}
HCL
cat > outputs.tf <<'HCL'
output "instance_profile_name" {
  value = aws_iam_instance_profile.app.name
}

output "artifacts_bucket" {
  value = aws_s3_bucket.artifacts.bucket
}
HCL
terraform init -migrate-state -force-copy -backend-config=../backend.hcl -input=false -no-color
rm -rf state terraform.tfstate terraform.tfstate.backup
terraform apply -auto-approve -no-color
cd ../app
sed -i 's/>= 1.7.0/>= 1.6.0/' main.tf
cat > backend.tf <<'HCL'
terraform {
  backend "s3" {
    key                  = "app/terraform.tfstate"
    workspace_key_prefix = "envs"
  }
}
HCL
cat > app.tf <<'HCL'
data "terraform_remote_state" "platform" {
  backend = "s3"
  config = {
    bucket = "tfstate-lab"
    key    = "platform/terraform.tfstate"
    region = "us-east-1"
  }
}

data "aws_ami" "amzn2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*"]
  }
}

resource "aws_instance" "app" {
  count = 1

  ami                  = data.aws_ami.amzn2.id
  instance_type        = terraform.workspace == "prod" ? "t3.small" : "t3.micro"
  iam_instance_profile = data.terraform_remote_state.platform.outputs.instance_profile_name

  tags = {
    Name            = "app-${terraform.workspace}"
    Workspace       = terraform.workspace
    ArtifactsBucket = data.terraform_remote_state.platform.outputs.artifacts_bucket
  }
}
HCL
terraform init -backend-config=../backend.hcl -input=false -no-color
terraform apply -auto-approve -no-color
for ws in staging prod; do
  terraform workspace new "$ws" -no-color
  terraform apply -auto-approve -no-color
done
cd ../reports
cat > inventory.tf <<'HCL'
data "aws_instance" "prod" {
  filter {
    name   = "tag:Name"
    values = ["app-prod"]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

data "aws_iam_instance_profile" "prod" {
  name = data.aws_instance.prod.iam_instance_profile
}

data "aws_s3_bucket" "artifacts" {
  bucket = "platform-artifacts"
}

resource "aws_s3_object" "inventory" {
  bucket       = data.aws_s3_bucket.artifacts.id
  key          = "inventory/prod.json"
  content_type = "application/json"
  content = jsonencode({
    instance_id   = data.aws_instance.prod.id
    instance_type = data.aws_instance.prod.instance_type
    role_arn      = data.aws_iam_instance_profile.prod.role_arn
  })
}
HCL
terraform init -input=false -no-color
terraform apply -auto-approve -no-color
terraform plan -no-color -detailed-exitcode
