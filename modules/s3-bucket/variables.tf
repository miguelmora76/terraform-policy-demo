variable "name" {
  description = "Bucket name. Lowercase letters, digits and hyphens, 3-63 characters."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.name))
    error_message = "name must be 3-63 characters of lowercase letters, digits and hyphens, starting and ending with a letter or digit."
  }
}

variable "environment" {
  description = "Deployment environment, recorded in the Environment tag."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "owner" {
  description = "Team that owns the bucket, recorded in the Owner tag."
  type        = string

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "owner must not be empty."
  }
}

variable "versioning_enabled" {
  description = "Keep object versions. Leave on unless you have a reason."
  type        = bool
  default     = true
}

variable "block_public_access" {
  description = "Block all public access. The module allows turning this off; the OPA policy in CI is what stops it reaching a plan."
  type        = bool
  default     = true
}

variable "expiration_days" {
  description = "Delete objects after this many days. null keeps them forever."
  type        = number
  default     = null

  validation {
    condition     = var.expiration_days == null || try(var.expiration_days >= 1, false)
    error_message = "expiration_days must be null or at least 1."
  }
}

variable "force_destroy" {
  description = "Allow destroying a non-empty bucket."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Extra tags. Environment, Owner, ManagedBy and ModuleVersion are set by the module and win on conflict."
  type        = map(string)
  default     = {}
}
