variable "name" {
  type    = string
  default = "linkly-course-github"
}

variable "repository" {
  description = "owner/name of the GitHub repository allowed to use the role, e.g. <you>/devops-course."
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.repository))
    error_message = "repository must be exactly owner/name, without wildcards."
  }
}

variable "state_bucket_arn" {
  description = "The Terraform state bucket (from ../../bootstrap)."
  type        = string
}
