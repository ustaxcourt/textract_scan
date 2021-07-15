import json
import os
import boto3
from botocore.config import Config

DESTINATION_TABLE_NAME = os.environ['DESTINATION_TABLE_NAME']

config = Config(
    retries={
        'max_attempts': 10,
        'mode': 'standard'
    }
)

dynamodb_client = boto3.client('dynamodb', config=config)


def add_contents_id(docket_number, docket_entry_id, document_contents_id):
    '''
    Writes the documentContentsId for this docket-entry row
    '''
    pk = f"case|{docket_number}"
    sk = f"docket-entry|{docket_entry_id}"
    resp = dynamodb_client.update_item(
        TableName=DESTINATION_TABLE_NAME,
        Key={
            'pk': {'S': pk},
            'sk': {'S': sk}
        },
        ConditionExpression='attribute_exists(pk) and attribute_exists(sk) and attribute_not_exists(documentContentsId)', # noqa 501
        UpdateExpression='SET documentContentsId = :documentContentsId',
        ExpressionAttributeValues={
            ':documentContentsId': {'S': document_contents_id}
        },
        ReturnValues="UPDATED_NEW"
    )
    return resp


def handler(event, context):
    '''
    Handles queue items from SQS that represent a row in the source
    dynamoDB table.

    It expects each queue item to have
    body: json string that parses to:
        docket_number: the docket number of the case
        docket_entry_id: the docket entry of the docket entry these contents belong to
        document_contents_id: the id of the document contents. i.e. the key for the s3 doc
    '''

    for record in event['Records']:
        item_info = json.loads(record["body"])
        try:
            add_contents_id(**item_info)
        except dynamodb_client.exceptions.ConditionalCheckFailedException:
            # many of these already have the documentContents don't overwrite
            pass

    return {
        'statusCode': 200,
        'body': f'Processed {len(event["Records"])} records'
    }
