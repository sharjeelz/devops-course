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

# Module 9: the inventory Ansible needs for this server.
#   terraform output -raw ansible_inventory > ../../../ansible/inventories/aws/hosts.yml
output "ansible_inventory" {
  value = yamlencode({
    all = {
      children = {
        linkly = {
          hosts = {
            linkly-course = {
              ansible_host    = module.server.public_ip
              ansible_user    = "ec2-user"
              linkly_base_url = "http://${module.server.public_ip}:8080"
            }
          }
        }
      }
    }
  })
}
