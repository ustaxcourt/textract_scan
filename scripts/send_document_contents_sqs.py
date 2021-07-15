import os
import json
import boto3
from botocore.config import Config


SOURCE_TABLE_NAME = 'textract-completed-ocr-efcms'

AWS_ACCESS_KEY_ID = os.environ["AWS_ACCESS_KEY_ID"]
AWS_SECRET_ACCESS_KEY = os.environ["AWS_SECRET_ACCESS_KEY"]


config = Config(
    region_name='us-east-1',
    retries={'max_attempts': 5}
)


def get_aws_clients():
    dynamodb_client = boto3.client(
        'dynamodb',
        config=config,
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY
    )

    sqs = boto3.resource(
        'sqs',
        config=config,
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY
    )
    Q_NAME = "process_document_contents_queue"
    queue = sqs.get_queue_by_name(QueueName=Q_NAME)

    return dynamodb_client, queue


def make_SQS_item(item):
    '''
    Converts a dynamoDB object into the proper object with a json Body for SQS
    with an Id and MessageBody

    >>> test_obj = {
    ...    'docket_number':{'S': '100-99'},
    ...    'docket_entry_id':{'S': 'abcdefg'},
    ...    'document_contents_id':{'S': '123456'}
    ... }
    >>> make_SQS_item(test_obj)
    {'Id': 'abcdefg', 'MessageBody': '{"docket_number": "100-99", "docket_entry_id": "abcdefg", "document_contents_id": "123456"}'}
    ''' # noqa 501

    d = {
        "docket_number": item['docket_number']['S'],
        "docket_entry_id": item['docket_entry_id']['S'],
        "document_contents_id": item['document_contents_id']['S']
    }
    body = json.dumps(d)
    entry = {
        'Id': d['docket_entry_id'],
        'MessageBody': body
    }
    return entry


def scanDDB(source_table_name, sqs_client, dynamodb_client):
    '''
    Scans the source table and writes the documentContents into the
    corresponding row in the destination table
    '''
    paginator = dynamodb_client.get_paginator('scan')
    response_iterator = paginator.paginate(TableName=source_table_name)

    item_count = 0
    batch_size = 10

    for page in response_iterator:
        print("item:", item_count)
        for index in range(0, len(page['Items']), batch_size):

            entries = [make_SQS_item(item) for item in page['Items'][index:index + batch_size]]

            item_count += len(entries)

            res = sqs_client.send_messages(Entries=entries)
            if 'failed' in res:
                print(res['failed'])


if __name__ == "__main__":
    dynamodb_client, queue = get_aws_clients()
    scanDDB(SOURCE_TABLE_NAME, queue, dynamodb_client)
