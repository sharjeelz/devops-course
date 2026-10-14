output "url" {
  description = "Linkly, once the instance has finished starting (a few minutes after apply)."
  value       = module.server.url
}

output "ssh_command" {
  value = module.server.ssh_command
}

output "backup_bucket" {
  value = module.backups.bucket_name
}

output "instance_id" {
  value = module.server.instance_id
}
