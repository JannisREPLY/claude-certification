output "instance_profile_name" {
  value = aws_iam_instance_profile.app.name
}

output "artifacts_bucket" {
  value = aws_s3_bucket.artifacts.bucket
}
