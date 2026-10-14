variable "name" {
  description = "Name for the VPC and its parts."
  type        = string
}

variable "cidr" {
  description = "The VPC's address range."
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.cidr, 0))
    error_message = "cidr must be a CIDR block, e.g. 10.0.0.0/16."
  }
}

variable "az_count" {
  description = "How many Availability Zones get a public subnet."
  type        = number
  default     = 2
  validation {
    condition     = var.az_count >= 1 && var.az_count <= 3
    error_message = "az_count must be 1, 2 or 3."
  }
}

variable "private_subnets" {
  description = "Also create private subnets (one per AZ) with no route to the internet."
  type        = bool
  default     = false
}

variable "public_subnet_tags" {
  description = "Extra tags for the public subnets, e.g. kubernetes.io/role/elb = 1 for EKS load balancers."
  type        = map(string)
  default     = {}
}
