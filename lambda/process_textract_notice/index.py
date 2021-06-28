import os
import json
import uuid
import boto3
from botocore.client import Config

config = Config(retries={"max_attempts": 30})
client = boto3.client('textract', config=config)
s3 = boto3.resource('s3')


def get_results(job_id):
    '''
    The docs say we need to check for success here
    what happens if the JobStatus is something else like IN_PROGRESS
    Can that happen even when this was reported to SNS?
    '''
    response = client.get_document_text_detection(JobId=job_id)

    # Careful, the Block does not always have a `Text` property
    text = ' '.join(b.get('Text', '') for b in response['Blocks'])
    next_token = response.get('NextToken')
    while next_token:
        response = client.get_document_text_detection(JobId=job_id, NextToken=next_token)
        text += ' '.join(b.get('Text', '') for b in response['Blocks'])
        next_token = response.get('NextToken')
    return text


def save_text(text, docket_number, docket_entry_id):
    # we don't really know where to save this yet
    output_bucket = os.environ['PDF_BUCKET']
    document_contents_id = str(uuid.uuid4())
    s3object = s3.Object(output_bucket, document_contents_id)
    content = {
        "documentContents": text,
        "docketNumber": docket_number,
        "docketEntryId": docket_entry_id
    }
    s3object.put(
        Body=(bytes(json.dumps(content).encode('UTF-8')))
    )


def handler(event, context):
    for record in event['Records']:
        body = json.loads(record["body"])
        job_return = json.loads(body['Message'])
        '''
        It looks like:
        {'JobId': 'bda653649672b8c530b2e4ab47c12f0245dbbdfac65b001ce13471d5016cc131',
         'Status': 'SUCCEEDED',
         'API': 'StartDocumentTextDetection',
         'JobTag': '7151-11',
         'Timestamp': 1624674335539,
         'DocumentLocation': {'S3ObjectName': 'sample.pdf',
         'S3Bucket': 'efcms-test-document-bucket'}
        }
        '''
        job_id = job_return['JobId']
        docket_number = job_return.get('JobTag')
        documentLocation = job_return.get('DocumentLocation')
        docketEntryId = None
        if documentLocation is not None:
            docketEntryId = documentLocation.get('S3ObjectName')
        text = get_results(job_id)
        save_text(text, docket_number, docketEntryId)
    return {
        'statusCode': 200,
        'body': f'Processed {len(event["Records"])} records'
    }
