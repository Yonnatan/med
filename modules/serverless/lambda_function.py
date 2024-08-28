import json
import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
table_name = 'ItemsTable'
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    http_method = event['httpMethod']
    
    if http_method == 'POST':
        item = json.loads(event['body'])
        table.put_item(Item=item)
        return {
            'statusCode': 201,
            'body': json.dumps(item)
        }

    elif http_method == 'GET':
        item_id = event['pathParameters']['id']
        response = table.get_item(Key={'ItemId': item_id})
        item = response.get('Item')
        if item:
            return {
                'statusCode': 200,
                'body': json.dumps(item)
            }
        else:
            return {
                'statusCode': 404,
                'body': json.dumps({'error': 'Item not found'})
            }

    elif http_method == 'DELETE':
        item_id = event['pathParameters']['id']
        table.delete_item(Key={'ItemId': item_id})
        return {
            'statusCode': 204
        }

    else:
        return {
            'statusCode': 405,
            'body': json.dumps({'error': 'Method not allowed'})
        }
