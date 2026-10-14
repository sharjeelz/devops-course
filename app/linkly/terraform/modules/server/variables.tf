variable "name" {
  description = "Name for the instance and everything that belongs to it."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  description = "A public subnet (from the network module)."
  type        = string
}

variable "allowed_cidr" {
  description = "The one address (a /32) allowed to reach SSH and Linkly."
  type        = string
}

variable "ssh_public_key" {
  description = "Your SSH public key (the contents of ~/.ssh/id_ed25519.pub)."
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "linkly_images" {
  description = "Where your images live, e.g. ghcr.io/<you>."
  type        = string
}

variable "linkly_tag" {
  description = "Which build to run, e.g. sha-abc1234."
  type        = string
}

variable "backup_bucket_arn" {
  description = "The only bucket this server may use."
  type        = string
}
