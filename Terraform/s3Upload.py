import boto3
import json
from urllib.parse import unquote_plus
import os


def lambda_handler(event, context):
    # Specify the S3 bucket name and object key
    # bucket_name = 'grp1-s3bucket'
    bucket_name = os.environ['BUCKET_NAME']

    s3 = boto3.client('s3')

    event_body = json.loads(event['body'])
    file_name = event_body.get('file_name', '')
    file_content = event_body.get('content', '')

    # Put the object in the specified S3 bucket
    try:
        s3.put_object(Bucket=bucket_name, Key=file_name, Body=file_content)
        return {
            'statusCode': 200,
            'body': 'Object successfully uploaded to S3!'
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': f'Error uploading object to S3: {str(e)}'
        }