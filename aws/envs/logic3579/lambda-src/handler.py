import json


def lambda_handler(event, context):
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(
            {
                "message": "Hello from logic3579",
                "request_id": context.aws_request_id,
            }
        ),
    }
