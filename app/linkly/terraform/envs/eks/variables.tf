variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "allowed_cidr" {
  description = "Your own address as a /32: the only one that may reach the Kubernetes API."
  type        = string
  validation {
    condition     = can(cidrnetmask(var.allowed_cidr)) && endswith(var.allowed_cidr, "/32") && !startswith(var.allowed_cidr, "0.0.0.0")
    error_message = "allowed_cidr must be one IPv4 address as a /32 (e.g. 203.0.113.10/32), never 0.0.0.0/0."
  }
}

variable "kubernetes_version" {
  type    = string
  default = "1.35"
}

variable "node_capacity_type" {
  description = "ON_DEMAND, or SPOT to save ~60% (nodes can be reclaimed)."
  type        = string
  default     = "ON_DEMAND"
}
