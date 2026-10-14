# Linkly's dev environment on AWS (module 7): the network, a backup bucket and the server, built from
# the modules in ../../modules. terraform apply → a working Linkly; terraform destroy → all gone.
module "network" {
  source = "../../modules/network"
  name   = "linkly-course"
}

module "backups" {
  source        = "../../modules/backups"
  name_prefix   = "linkly-course-backups"
  force_destroy = true # a course environment: destroy may take the backups with it
}

module "server" {
  source            = "../../modules/server"
  name              = "linkly-course"
  vpc_id            = module.network.vpc_id
  subnet_id         = module.network.public_subnet_ids[0]
  allowed_cidr      = var.allowed_cidr
  ssh_public_key    = var.ssh_public_key
  instance_type     = var.instance_type
  linkly_images     = var.linkly_images
  linkly_tag        = var.linkly_tag
  backup_bucket_arn = module.backups.bucket_arn
}
