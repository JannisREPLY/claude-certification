set -euo pipefail
sed -i 's/version = "~> 4.67"/version = ">= 4.67"/' modules/logs/main.tf
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

resource "aws_vpc" "dr" {
  provider   = aws.west
  cidr_block = "10.20.0.0/16"

  tags = {
    Name = "dr"
  }
}''')
open("main.tf", "w").write(s)
PY
terraform init -upgrade -input=false -no-color
terraform apply -auto-approve -no-color
