output "report_instance_id" {
  value = aws_instance.report.id
}

output "db_config" {
  value = aws_s3_object.db_config.content
}

output "debug_connection" {
  value = "postgres://${var.db_username}:${var.db_password}@db.orders.internal/orders"
}
