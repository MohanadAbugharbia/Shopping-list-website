import json
import boto3

client = boto3.client("sqs")

def lambda_handler(event, context):

    # TODO implement
    messageBody = []
    entries = []
    for i in range(100):
        response = client.receive_message(
            QueueUrl = "https://sqs.eu-central-1.amazonaws.com/269907780387/SLW-queue-terraform",
            MaxNumberOfMessages=1
            )
        try:
            response["Messages"]
        except:
            break
        messageBody.append(response["Messages"][0]["Body"])
        entries.append({"Id" : response["Messages"][0]["MessageId"], "ReceiptHandle" : response["Messages"][0]["ReceiptHandle"]})
    print(messageBody)
    return {
        'statusCode': 200,
        'body': json.dumps(messageBody)
        
    }
