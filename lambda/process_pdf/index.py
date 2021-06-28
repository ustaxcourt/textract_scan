import os
import boto3
from botocore.client import Config

'''
This lambda function should listen to an SQS Queue which will
relay information about a PDF document to be scanned.

Note: The maximum document size for asynchronous operations is 500 MB for PDF files.
Also, the rate limit for asyn calls to GetDocumentTextDetection is 10/second:
    https://docs.aws.amazon.com/general/latest/gr/textract.html

It will expect the queue item to have:

body -- the object name in s3 -- that's probably the docketEntryId. This will be used as
the ClientRequestToken for Textract which means it must conform to ^[a-zA-Z0-9-_]+$
UUIDs used for docketEntryIds will validate

message attribute:
docket_number: the docket_number of the case. This will be passed as the job tag
of the Textract job, allowing us to recover it when the async job has finished
'''


def startJob(bucket_name, object_name, docket_number, sns_topic, sns_role):
    '''
    Sends an async job to Textract for processing.

    Arguments:
    bucket_name -- the name of the bucket where the original PDF is
    object_name -- the filename of the document. This will generally be the docketEntryID
                   must validate with ^[a-zA-Z0-9-_]+$
    docket_number -- the case number. It will be passed as a tag in case we want in after processing
    sns_topic -- The ARN of the notification channel to post results
    sns-role -- ARN of the role to use sending to SNS
    '''
    config = Config(
        retries={"max_attempts": 30}
    )
    client = boto3.client('textract', config=config)

    params = dict(
        ClientRequestToken=object_name,
        DocumentLocation={
            'S3Object': {
                'Bucket': bucket_name,
                'Name': object_name
            }
        },
        NotificationChannel={
            "RoleArn": sns_role,
            "SNSTopicArn": sns_topic
        }
    )
    # start_document_text_detection is picky about parameter types
    # we can't pass None or an empty string as the JobTag, so only
    # add the parameter if we actually have a value
    if docket_number is not None:
        params['JobTag'] = docket_number

    response = client.start_document_text_detection(**params)

    return response["JobId"]


def handler(event, context):
    '''
    Handles queued pdfs to be processed

    It expects each queue item to have
    body -- the filename of the object in s3 (probably the docketEntryID)
    messageAttributes --
        docket_number -- the docketNumber in case we want to write this to the output
    '''
    sns_topic = os.environ['SNS_TOPIC_ARN']
    sns_role = os.environ['SNS_ROLE_ARN']
    document_bucket = os.environ['PDF_BUCKET']

    for record in event['Records']:
        docket_entry_id = record["body"]
        docket_number = record['messageAttributes'].get('docket_number', {}).get('stringValue')
        startJob(document_bucket, docket_entry_id, docket_number, sns_topic, sns_role)

    return {
        'statusCode': 200,
        'body': f'Processed {len(event["Records"])} records'
    }
