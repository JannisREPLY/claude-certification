set -euo pipefail
terraform init -input=false -no-color
terraform apply -auto-approve -input=false -no-color
aws autoscaling set-desired-capacity --auto-scaling-group-name orders-workers --desired-capacity 4
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names orders-workers --query 'AutoScalingGroups[0].AutoScalingGroupARN' --output text > "$LAB_STATE/asg_arn"
terraform state show -no-color aws_launch_template.worker | sed -n 's/^ *id *= *"\(.*\)"/\1/p' > "$LAB_STATE/lt_id"
