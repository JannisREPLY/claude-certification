set -euo pipefail
sed -i 's/version = "~> 4.67"/version = "~> 5.0"/' modules/reports/main.tf
python3 - <<'PY'
s = open("main.tf").read()
s = s.replace('version = "3.1.0"', 'version = "~> 3.6.0"')
s = s.replace('''provider "aws" {
  region = "us-east-1"
}''', '''provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      ManagedBy = "terraform"
    }
  }
}

provider "aws" {
  alias  = "west"
  region = "us-west-2"

  default_tags {
    tags = {
      ManagedBy = "terraform"
    }
  }
}

resource "aws_s3_bucket" "replica" {
  provider = aws.west
  bucket   = "acme-reports-west"
}''')
open("main.tf", "w").write(s)
PY
terraform init -upgrade -input=false -no-color
terraform apply -auto-approve -input=false -no-color
terraform plan -input=false -no-color -detailed-exitcode
