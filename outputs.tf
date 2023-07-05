output "healthcheck_arns" {
  description = "Defined CloudWatch metric alarms, to connect to SNS etc"
  value       = toset([for each in aws_cloudwatch_metric_alarm.local_healthchecks : each.arn])
}
