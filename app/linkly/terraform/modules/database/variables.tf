variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Private subnets in two AZs or more."
  type        = list(string)
}

variable "allowed_security_group_id" {
  description = "The security group allowed to connect (the EKS cluster's)."
  type        = string
}

variable "engine_version" {
  type    = string
  default = "16"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  description = "Course setting: destroy without keeping a final snapshot. In production: false."
  type        = bool
  default     = true
}
