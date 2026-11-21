set -euo pipefail
trust() {
  printf '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":"%s"},"Action":"sts:AssumeRole"}]}' "$1"
}
aws iam create-user --user-name terraform-ci > /dev/null
key=$(aws iam create-access-key --user-name terraform-ci --query AccessKey --output json)
id=$(jq -r .AccessKeyId <<< "$key")
secret=$(jq -r .SecretAccessKey <<< "$key")
echo "$id" > "$LAB_STATE/key-id"
echo "$secret" > "$LAB_STATE/secret"
for role in terraform-deploy terraform-audit; do
  aws iam create-role --role-name "$role" --assume-role-policy-document "$(trust arn:aws:iam::123456789012:user/terraform-ci)" > /dev/null
done
aws iam put-role-policy --role-name terraform-deploy --policy-name deploy \
  --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"*","Resource":"*"}]}'
aws iam put-role-policy --role-name terraform-audit --policy-name audit \
  --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["iam:*","sts:GetCallerIdentity"],"Resource":"*"}]}'
secrets=/home/coder/secrets
rm -rf "$secrets" && mkdir -p "$secrets" && chmod 700 "$secrets"
printf '[ci]\naws_access_key_id = %s\naws_secret_access_key = %s\n' "$id" "$secret" > "$secrets/credentials"
printf '[profile ci]\nregion = us-east-1\noutput = json\n' > "$secrets/config"
chmod 600 "$secrets"/*
if [ "$LEVEL" = expert ]; then
  printf 'aws_access_key = "%s"\naws_secret_key = "%s"\n' "$id" "$secret" > terraform.tfvars
fi
cp modules/audit/main.tf "$LAB_STATE/audit.tf"
sed -i '1,4d' modules/audit/main.tf
terraform init -input=false -no-color
cp "$LAB_STATE/audit.tf" modules/audit/main.tf
