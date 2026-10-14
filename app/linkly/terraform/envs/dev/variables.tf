variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "allowed_cidr" {
  description = "Your own address as a /32 (curl -s https://checkip.amazonaws.com): the only one that may reach SSH and Linkly."
  type        = string
  validation {
    condition     = can(cidrhost(var.allowed_cidr, 0)) && endswith(var.allowed_cidr, "/32") && !startswith(var.allowed_cidr, "0.0.0.0")
    error_message = "allowed_cidr must be one address as a /32 (e.g. 203.0.113.10/32), never 0.0.0.0/0."
  }
}

variable "ssh_public_key" {
  description = "Your SSH public key, e.g. the contents of ~/.ssh/id_ed25519.pub."
  type        = string
  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256) ", var.ssh_public_key))
    error_message = "ssh_public_key must be a public key line (ssh-ed25519 AAAA...), not a private key."
  }
}

variable "linkly_images" {
  description = "Where your images live, e.g. ghcr.io/<you> (lowercase)."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9.-]+(/[a-z0-9._-]+)+$", var.linkly_images))
    error_message = "linkly_images must be a lowercase registry path such as ghcr.io/<you>."
  }
}

variable "linkly_tag" {
  description = "Which build to run: a sha-... tag from your packages page."
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+$", var.linkly_tag)) && var.linkly_tag != "latest"
    error_message = "linkly_tag must be a pinned build such as sha-abc1234 (not latest)."
  }
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}
