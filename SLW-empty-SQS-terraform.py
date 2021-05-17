import json
import boto3

client = boto3.client("sqs")

def lambda_handler(event, context):
    # TODO implement
    entries = []
    messageBody = []
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
        
    try:
        messages_delete = client.delete_message_batch(
            QueueUrl='https://sqs.eu-central-1.amazonaws.com/269907780387/SLW-queue-terraform',
            Entries=entries
        )
        print(messages_delete)
        
        return {
            'statusCode': 200,
            'body': json.dumps(messageBody)
        }
    except:
        print("There are no messages to delete")
        return {
            'statusCode' : 200,
            'body' : json.dumps('There are no messages to delete')
        }
