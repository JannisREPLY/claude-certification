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
terraform init -migrate-state -force-copy -input=false -no-color
rm -f terraform.tfstate terraform.tfstate.backup
terraform plan -no-color -detailed-exitcode
cd ../app
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
  instance_type        = "t3.micro"
  iam_instance_profile = data.terraform_remote_state.platform.outputs.instance_profile_name

  tags = {
    Name = "app-${terraform.workspace}"
  }
}
HCL
terraform init -input=false -no-color
terraform apply -auto-approve -no-color
terraform workspace new staging -no-color
terraform apply -auto-approve -no-color
terraform plan -no-color -detailed-exitcode
