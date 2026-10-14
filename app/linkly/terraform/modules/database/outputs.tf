output "host" {
  description = "The database's address (externalDatabase.host in the chart)."
  value       = aws_db_instance.this.address
}

output "secret_arn" {
  description = "The Secrets Manager secret with the username and password (externalDatabase.externalSecret.remoteKey)."
  value       = one(aws_db_instance.this.master_user_secret).secret_arn
}
