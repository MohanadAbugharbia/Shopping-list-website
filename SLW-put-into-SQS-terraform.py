import json
import boto3

client = boto3.client("sqs")

def lambda_handler(event, context):
    # TODO implement
    item = event["queryStringParameters"]["item"]
    response = client.send_message(
        QueueUrl = "https://sqs.eu-central-1.amazonaws.com/269907780387/SLW-queue-terraform",
        MessageBody = item
        )
    print(response)
    return {
        'statusCode': 200,
        'body': json.dumps(f'Placed {item} into the shopping list')
    }
