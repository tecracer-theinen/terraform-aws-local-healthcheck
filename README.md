# README

Terraform module to create local on-instance healthchecks which integrate into CloudWatch alerts.

With many software solutions you have healthchecks available under a URL which is only available on `localhost`. These healtchecks might show the status of different solution components and are hard to monitor without installing specific agents or rebinding the interface to a reachable interface.

This Terraform module aims at easy scheduling of local healthchecks, pushing them to CloudWatch Logs and defining relating CloudWatch Alerts which you can wire up to notification systems of your choice.

It creates an EventBridge schedule to execute a specific command (see `flavor` input) on the instance, retrieve the output via Lambda and push it to CloudWatch Logs. When any CloudWatch alarms are configured (see `cloudwatch_alarms` input), it will also create a related metric and alarm.

## Prerequisites

Instances targeted must be SSM-enabled or account-wide SSM Default Host Management Configuration must be active.

## Usage

```hcl
module "healthchecks" {
  source  = "tecracer-theinen/terraform-aws-local-healthcheck"
  version = "0.1.0"

  name         = "serverstatus"
  instance_ids = ["i-123456789012"]
  local_url    = "http://localhost:8000/_status"
}
```

### Variables

#### `name` (required)

Type: `string`

Will determine naming of resources such as CloudWatch Log Group, Metric Namespace, and Alert.

#### `instance_ids` (required):

Type: List of `string`

One or more instances which should run this healthcheck. Usually, they have the same software installed or run as a cluster

#### `local_url` (required):

Type: `string`

URL to check. Usually, of format `http://localhost:8000/_status`.

#### `cloudwatch_alarms`

Type: List of name(`string`), json_filter(`string`), periods (`number`=3)

Optional list of CloudWatch alerts to be set up. Each alert has a name, a CloudWatch JSON filter, and a number of periods to check. With this option you can set up multiple alerts, if the JSON response contains multiple items of interest.

Example:

```hcl
cloudwatch_alarms = [
  ["IAMSuccesses", "{ $.Code = \"Success\" }", 5],
  ["CorrectProfile", "{ $.InstanceProfileId = \"AIPAEXAMPLE12345678\" }", 2]
]
```

If one response does _not_ match within the configured amount of periods, the CloudWatch alert will trigger.

#### `interval`

Type: `number` = 3

Interval in minutes to execute healthcheck in.

#### `flavor`

Type: String
Valid: `curl`(default), `wget`, `powershell`

Command to execute locally on the instance to retrieve health check.

### Outputs

#### `healthcheck_arns`

Type: List of `aws_cloudwatch_metric_alarm` ARNs
.
Use these to wire the alerts up to the notification system of your choice.

## TODO

- Include ability to target instances by tag
- Add optional authentication methods for the URL (Headers, ...)
