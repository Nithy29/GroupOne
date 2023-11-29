import boto3
import json
import os
import uuid

dynamodb_table_name = os.environ['DYNAMODB_TABLE']
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(dynamodb_table_name)

def lambda_handler(event, context):
    
    abc = json.loads(event['body'])
    http_method = abc.get('dynamoDB_action')
    
    
    if http_method == 'POST':
        return create_item(event)
    elif http_method == 'UPDATE':
        return update_item(event)
    elif http_method == 'DELETE':
        return delete_item(event)
    elif http_method == 'GET_ALL':
        return get_items(event)
    elif http_method == 'GET_SINGLE_ITEM':
        return get_item_by_id(event)

    else:
        return {
            'statusCode': 400,
            'body': json.dumps({'message': 'Invalid method'})
        }

def create_item(event):
    body = json.loads(event['body'])

    # Generate a unique identifier for the 'id' field
    generated_id = str(uuid.uuid4())

    # Assume 'id' is a string attribute in your DynamoDB table
    item = {
        'id': generated_id,
        'data': body.get('data')
    }

    # Put item into DynamoDB
    response = table.put_item(Item=item)

    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Data added successfully', 'generated_id': generated_id})
    }

def update_item(event):
    body = json.loads(event['body'])
    
    generated_id = body.get('pathParameters', {}).get('id')

   
    # Generate an expression attribute name for "data" to avoid conflicts with reserved keywords
    expression_attribute_names = {'#data': 'data'}

    # Generate an update expression using the expression attribute name
    update_expression = 'SET #data = :data'
    
    # Define the attribute values
    expression_attribute_values = {':data': body.get('data')}

    # Perform the update operation
    response = table.update_item(
        Key={'id': generated_id},
        UpdateExpression=update_expression,
        ExpressionAttributeNames=expression_attribute_names,
        ExpressionAttributeValues=expression_attribute_values,
        ReturnValues='ALL_NEW'  # Change as needed
    )

    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Data updated successfully', 'updated_item': response['Attributes']})
    }

def delete_item(event):
    body = json.loads(event['body'])
    
    item_id = body.get('pathParameters', {}).get('id')
    print("ITEM ID AMMAR :" , item_id)
    
    # generated_id = body.get('pathParameters', {}).get('id')

    # Delete item from DynamoDB
    response = table.delete_item(
        Key={'id': item_id}
    )

    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Data deleted successfully'})
    }

def get_item_by_id(event):
    
    body = json.loads(event['body'])
    item_id = body.get('pathParameters', {}).get('id')

    # Get a single item by ID from DynamoDB
    response = table.get_item(
        Key={'id': item_id}
    )

    item = response.get('Item')
    if item:
        return {
            'statusCode': 200,
            'body': json.dumps(item)
        }
    else:
        return {
            'statusCode': 404,
            'body': json.dumps({'message': 'Item not found'})
        }

def get_items(event):
    # Fetch all items from DynamoDB
    response = table.scan()
    print("RESPONSE AMMAR AHMAD : " , response)
    return {
        'statusCode': 200,
        'body': json.dumps(response['Items'])
    }
