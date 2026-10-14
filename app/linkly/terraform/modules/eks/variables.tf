variable "name" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.35"
}

variable "subnet_ids" {
  description = "Where the nodes (and the control plane's network interfaces) go: two AZs or more."
  type        = list(string)
}

variable "endpoint_allowed_cidrs" {
  description = "Addresses allowed to reach the Kubernetes API (kubectl), e.g. [\"203.0.113.10/32\"]."
  type        = list(string)
  validation {
    condition     = length(var.endpoint_allowed_cidrs) > 0 && alltrue([for c in var.endpoint_allowed_cidrs : !startswith(c, "0.0.0.0/")])
    error_message = "endpoint_allowed_cidrs must list your own addresses, never 0.0.0.0/0."
  }
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"] # 2 vCPU, 4 GiB: room for the add-ons and Linkly; t3.small runs out of pod slots
}

variable "node_capacity_type" {
  description = "ON_DEMAND, or SPOT (cheaper, but AWS may take a node back with 2 minutes' notice)."
  type        = string
  default     = "ON_DEMAND"
  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "node_min" {
  type    = number
  default = 2
}

variable "node_max" {
  type    = number
  default = 3
}

variable "readable_secret_arns" {
  description = "The Secrets Manager secrets External Secrets may read (the database's)."
  type        = list(string)
}
