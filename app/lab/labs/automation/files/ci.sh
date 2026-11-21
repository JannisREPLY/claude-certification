#!/usr/bin/env bash
set -euo pipefail

terraform init
terraform plan -var "app_version=$BUILD_VERSION"
terraform apply -var "app_version=$BUILD_VERSION"
