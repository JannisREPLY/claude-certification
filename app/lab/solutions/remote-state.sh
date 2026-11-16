set -euo pipefail
cd network
cat > backend.tf <<'HCL'
terraform {
  backend "s3" {
    bucket         = "tfstate-lab"
    key            = "network/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-locks"
    encrypt        = true
  }
}
HCL
terraform init -migrate-state -force-copy -input=false -no-color
rm -f terraform.tfstate terraform.tfstate.backup
terraform plan -no-color | tail -1
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
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "tfstate-lab"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

resource "aws_security_group" "app" {
  name   = "app-${terraform.workspace}"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id
}
HCL
terraform init -input=false -no-color
terraform apply -auto-approve -no-color
terraform workspace new staging -no-color
terraform apply -auto-approve -no-color
