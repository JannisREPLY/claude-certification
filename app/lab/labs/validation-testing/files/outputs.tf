output "report_instance_id" {
  value = aws_instance.report.id
}

output "db_config" {
  value = aws_s3_object.db_config.content
}
