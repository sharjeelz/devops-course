output "instance_id" {
  value = aws_instance.this.id
}

output "public_ip" {
  value = aws_instance.this.public_ip
}

output "url" {
  value = "http://${aws_instance.this.public_ip}:8080"
}

output "ssh_command" {
  value = "ssh ec2-user@${aws_instance.this.public_ip}"
}

output "user_data" {
  description = "The start-up script, as rendered (handy for tests and debugging)."
  value       = local.user_data
}
