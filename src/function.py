import os
from datetime import datetime

import boto3


def lambda_handler(event, context):
    parse_and_post(event, os.getenv("NAMESPACE"))


def parse_and_post(data, namespace):
    output, time = get_invocation_data(data["command_id"], data["instance_id"])

    time_ts = datetime.strptime(time, "%Y-%m-%dT%H:%M:%S.%fZ").timestamp()

    create_stream_if_missing(namespace, data["instance_id"])
    put_log_event(namespace, data["instance_id"], time_ts, output)


def get_invocation_data(command_id, instance_id):
    ssm = boto3.client("ssm")
    response = ssm.get_command_invocation(CommandId=command_id, InstanceId=instance_id)

    output = response["StandardOutputContent"]
    time = response["ExecutionEndDateTime"]

    return (output, time)


def create_stream_if_missing(loggroup, logstream):
    logs = boto3.client("logs")

    response = logs.describe_log_streams(
        logGroupName=loggroup, logStreamNamePrefix=logstream
    )

    if len(response["logStreams"]) == 0:
        logs.create_log_stream(logGroupName=loggroup, logStreamName=logstream)


def put_log_event(loggroup, logstream, timestamp, message):
    logs = boto3.client("logs")
    logs.put_log_events(
        logGroupName=loggroup,
        logStreamName=logstream,
        logEvents=[{"timestamp": int(timestamp * 1000), "message": message}],
    )
