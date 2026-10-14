variable "name_prefix" {
  description = "Start of the bucket's name (AWS adds a unique suffix)."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,35}$", var.name_prefix))
    error_message = "name_prefix: lowercase letters, digits and dashes, at most 36 characters."
  }
}

variable "force_destroy" {
  description = "Let terraform destroy delete the bucket even with backups in it. Fine for a course; think twice in production."
  type        = bool
  default     = false
}
