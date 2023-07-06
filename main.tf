resource "aws_ssm_document" "local_healthcheck_curl" {
  count = local.ssm_document == "local_healthcheck_curl" ? 1 : 0

  name            = "local_healthcheck_${local.name}"
  document_format = "YAML"
  document_type   = "Command"

  content = <<-YAML
    schemaVersion: "2.2"
    description: "Perform local healthcheck (${var.name})"
    mainSteps:
      - action: "aws:runShellScript"
        name: "RetrieveHealthStatus"
        inputs:
          runCommand:
            - "curl --location-trusted \"${var.local_url}\" --silent"
  YAML
}

resource "aws_ssm_document" "local_healthcheck_wget" {
  count = local.ssm_document == "local_healthcheck_wget" ? 1 : 0

  name            = "local_healthcheck_${local.name}"
  document_format = "YAML"
  document_type   = "Command"

  content = <<-YAML
    schemaVersion: "2.2"
    description: "Perform local healthcheck (${var.name})"
    mainSteps:
      - action: "aws:runShellScript"
        name: "RetrieveHealthStatus"
        inputs:
          runCommand:
            - "wget \"${var.local_url}\" --quiet --output-document=-"
  YAML
}

resource "aws_ssm_document" "local_healthcheck_powershell" {
  count = local.ssm_document == "local_healthcheck_powershell" ? 1 : 0

  name            = "local_healthcheck_${local.name}"
  document_format = "YAML"
  document_type   = "Command"

  content = <<-YAML
    schemaVersion: "2.2"
    description: "Perform local healthcheck (${var.name})"
    mainSteps:
      - action: "aws:runPowerShellScript"
        name: "RetrieveHealthStatus"
        inputs:
          runCommand:
            - "Invoke-WebRequest \"${var.local_url}\" | Select Content | Write-Host"
  YAML
}

resource "aws_scheduler_schedule" "local_healthcheck" {
  name       = "local_healthcheck_${local.name}"
  group_name = aws_scheduler_schedule_group.local_healthchecks.name

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "rate(${var.interval} minutes)"

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ssm:sendCommand"
    role_arn = aws_iam_role.local_healthcheck_scheduler.arn

    input = jsonencode({
      DocumentName = "local_healthcheck_${local.name}"
      InstanceIds  = var.instance_ids
    })
  }
}

resource "aws_scheduler_schedule_group" "local_healthchecks" {
  name = "local_healthcheck_${local.name}"
}

resource "aws_iam_role" "local_healthcheck_scheduler" {
  name        = "local_healthcheck_${local.name}_scheduler"
  description = "SSM-based Health Check Role"

  inline_policy {
    name = "InlinePolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "InvokeCommand"
          Effect   = "Allow"
          Action   = "ssm:SendCommand"
          Resource = "arn:aws:ssm:${local.region}:${local.account_id}:document/local_healthcheck_${local.name}"
        },
        {
          Sid    = "InvokeOnInstances"
          Effect = "Allow"
          Action = "ssm:SendCommand"
          Resource = toset([
            for k, v in var.instance_ids : "arn:aws:ec2:${local.region}:${local.account_id}:instance/${v}"
          ])
        }
      ]
    })
  }

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = [
          "scheduler.amazonaws.com",
          "ssm.amazonaws.com"
        ]
      }
    }]
  })
}

resource "aws_cloudwatch_event_rule" "local_healthcheck" {
  name        = "local_healthcheck_${local.name}"
  description = "Process result of invocation"

  event_pattern = jsonencode({
    source      = ["aws.ssm"]
    detail-type = ["EC2 Command Invocation Status-change Notification"]
    detail = {
      status = ["Success"]
    }
  })
}

resource "aws_cloudwatch_event_target" "local_healthcheck" {
  rule = aws_cloudwatch_event_rule.local_healthcheck.name
  arn  = module.lambda_function.lambda_function_arn

  input_transformer {
    input_paths = {
      instance_id = "$.detail.instance-id",
      command_id  = "$.detail.command-id"
    }
    input_template = "{ \"instance_id\": \"<instance_id>\", \"command_id\": \"<command_id>\" }"
  }
}

module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "4.18.0"

  function_name = "local_healthcheck_${local.name}"
  description   = "Retrieve input and transform for CW Logs"
  publish       = true
  timeout       = 10

  runtime     = "python3.10"
  handler     = "function.lambda_handler"
  source_path = "${path.module}/src/"

  environment_variables = {
    NAMESPACE = var.name
  }

  allowed_triggers = {
    EventBridge = {
      principal  = "events.amazonaws.com"
      source_arn = aws_cloudwatch_event_rule.local_healthcheck.arn
    }
  }

  attach_policy_statements = true
  policy_statements = {
    logs = {
      effect = "Allow"
      actions = [
        "logs:PutLogEvents",
        "logs:DescribeLogStreams",
        "logs:CreateLogStream"
      ]
      resources = [
        "${aws_cloudwatch_log_group.local_healthchecks.arn}:log-stream:*"
      ]
    },
    getssm = {
      effect = "Allow"
      actions = [
        "ssm:GetCommandInvocation"
      ]
      resources = [
        "arn:aws:ssm:${local.region}:${local.account_id}:*"
      ]
    }
  }
}

resource "aws_cloudwatch_log_group" "local_healthchecks" {
  name              = local.name
  retention_in_days = local.log_retention_days
}

resource "aws_cloudwatch_log_metric_filter" "local_healthchecks" {
  for_each = { for i, v in var.cloudwatch_alarms : i => v }

  name           = "local_healthcheck_${local.name}_${lower(each.value[0])}"
  pattern        = each.value[1]
  log_group_name = aws_cloudwatch_log_group.local_healthchecks.name

  metric_transformation {
    namespace     = var.name
    name          = each.value[0]
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "local_healthchecks" {
  for_each = { for i, v in var.cloudwatch_alarms : i => v }

  namespace   = var.name
  metric_name = each.value[0]
  alarm_name  = "${local.name}_${lower(each.value[0])}"

  evaluation_periods  = length(each.value) > 2 ? each.value[2] : local.monitor_periods
  period              = 60 * var.interval
  comparison_operator = "LessThanThreshold"
  threshold           = 1
  treat_missing_data  = "breaching"
  statistic           = "Average"
}
