variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "repository" {
  description = "Your fork, as owner/name (e.g. <you>/devops-course)."
  type        = string
}

variable "state_bucket" {
  description = "The state bucket's name (terraform output -raw state_bucket in ../../bootstrap)."
  type        = string
}
