set -euo pipefail
cd platform
cat > backend.tf <<'HCL'
terraform {
  backend "s3" {
    bucket         = "tfstate-lab"
    key            = "platform/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-locks"
    encrypt        = true
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
terraform init -migrate-state -force-copy -input=false -no-color
rm -f terraform.tfstate terraform.tfstate.backup
terraform apply -auto-approve -no-color
cd ../app
sed -i 's/>= 1.7.0/>= 1.6.0/' main.tf
cat > backend.tf <<'HCL'
terraform {
  backend "s3" {
    bucket         = "tfstate-lab"
    key            = "app/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-locks"
    encrypt        = true
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
  ami                  = data.aws_ami.amzn2.id
  instance_type        = terraform.workspace == "prod" ? "t3.small" : "t3.micro"
  iam_instance_profile = "app-runtime-profile"

  tags = {
    Name            = "app-${terraform.workspace}"
    ArtifactsBucket = data.terraform_remote_state.platform.outputs.artifacts_bucket
  }
}
HCL
terraform init -input=false -no-color
terraform apply -auto-approve -no-color
for ws in staging prod; do
  terraform workspace new "$ws" -no-color
  terraform apply -auto-approve -no-color
done
terraform plan -no-color -detailed-exitcode
