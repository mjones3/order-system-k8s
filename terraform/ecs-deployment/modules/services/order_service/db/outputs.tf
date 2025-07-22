output "rds_endpoint" {
  description = "The endpoint (address) of the RDS instance"
  value       = aws_db_instance.this.address
}

output "rds_port" {
  description = "The port on which the RDS instance is listening"
  value       = aws_db_instance.this.port
}

output "jdbc_connection_string" {
  description = "The JDBC connection string for the RDS PostgreSQL instance"
  value       = format("jdbc:postgresql://%s:%s/<database>", aws_db_instance.this.address, aws_db_instance.this.port)
}
