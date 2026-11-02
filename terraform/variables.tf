variable "project_name" {
  description = "Project identifier"
  type        = string
  default     = "disaster-recovery-mesh"
}

variable "environment" {
  description = "Target deployment environment"
  type        = string
  default     = "prod"
}

variable "primary_region" {
  description = "Primary operational region (Canada)"
  type        = string
  default     = "ca-central-1"
}

variable "secondary_region" {
  description = "Secondary disaster recovery failover region (US)"
  type        = string
  default     = "us-east-1"
}
