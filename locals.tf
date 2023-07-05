locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  name               = lower(var.name)
  log_retention_days = 90
  monitor_periods    = 3

  ssm_document = var.flavor == "curl" ? "local_healthcheck_curl" : var.flavor == "wget" ? "local_healthcheck_wget" : "local_healthcheck_powershell"
}
