variable "name" {
  description = "Name of this healthcheck (no spaces allowed)"
  type        = string

  validation {
    condition     = !strcontains(var.name, " ")
    error_message = "No spaces are allowed in the name"
  }
}

variable "instance_ids" {
  type        = list(string)
  default     = []
  description = "List of Instance IDs to target"
}

variable "local_url" {
  type        = string
  description = "Local URL to check"
}

variable "cloudwatch_alarms" {
  description = "CloudWatch alarms (name, json_filter_query, monitor_periods)"
  type        = list(tuple([string, string, number]))
  default     = []
}

variable "interval" {
  description = "Interval to execute healthcheck (in minutes)"
  type        = number
  default     = 5
}

variable "flavor" {
  description = "Which flavor of command to use for checking"
  type        = string
  default     = "curl"

  validation {
    condition     = contains(["curl", "wget", "powershell"], var.flavor)
    error_message = "Valid values for flavor are (curl, wget, powershell)."
  }
}
