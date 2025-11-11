import json
import os
import boto3
import uuid


# --- 1. Initialize Boto3 Client ---
    # Use os.environ to securely retrieve the table name set by Terraform
INVENTORY_TABLE_NAME = os.environ.get('INVENTORY_TABLE_NAME', 'InventoryTable')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(INVENTORY_TABLE_NAME)


# --- 2. Standard API Gateway Response Function ---
    # This ensures all responses are formatted correctly for API Gateway
def build_response(status_code, body=None):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            # CORS headers are good practice for APIs
            'Access-Control-Allow-Origin': '*' 
        },
        'body': json.dumps(body) if body is not None else '{}'
    }

# POST/CREATE - CRUD
def create_item(body):
    # Ensure body is parsed (API Gateway input is a string)
    item = json.loads(body)
    
    # Generate a unique ID if not provided (best practice for POST)
    if 'id' not in item:
        item['id'] = str(uuid.uuid4())
    
    try:
        table.put_item(Item=item)
        return build_response(201, {'message': 'Item created', 'id': item['id']})
    except Exception as e:
        print(f"Error creating item: {e}")
        return build_response(500, {'message': 'Failed to create item'})

# GET SINGLE - CRUD    
def get_item(path_params):
    if path_params is None or 'id' not in path_params:
        return build_response(400, {'message': 'Missing item ID'})
    
    item_id = path_params['id']
    
    response = table.get_item(Key={'id': item_id})
    
    if 'Item' in response:
        return build_response(200, response['Item'])
    else:
        return build_response(404, {'message': 'Item not found'})

# GET ALL - CRUD    
def get_all_items():
    # Warning: Scan reads all items in the table. Use wisely!
    response = table.scan()
    return build_response(200, response['Items'])

# UPDATE/PUT/PATCH - CRUD
def update_item(path_params, body):
    if path_params is None or 'id' not in path_params:
        return build_response(400, {'message': 'Missing item ID'})
    
    item_id = path_params['id']
    updates = json.loads(body)

    # Use Expression-based updates for efficiency (best practice)
    # This loop dynamically creates the UpdateExpression string
    update_expression = "set "
    expression_attribute_values = {}
    
    for key, value in updates.items():
        if key != 'id':
            update_expression += f"#{key} = :{key},"
            expression_attribute_values[f":{key}"] = value
            
    # Remove trailing comma
    update_expression = update_expression.rstrip(',')

    # Use ExpressionAttributeNames to map attributes that might be reserved words (like 'name')
    expression_attribute_names = {f"#{key}": key for key in updates.keys() if key != 'id'}
    
    try:
        table.update_item(
            Key={'id': item_id},
            UpdateExpression=update_expression,
            ExpressionAttributeValues=expression_attribute_values,
            ExpressionAttributeNames=expression_attribute_names,
            ReturnValues="UPDATED_NEW" # Get the updated values back
        )
        return build_response(200, {'message': f'Item {item_id} updated'})
    except Exception as e:
        print(f"Error updating item: {e}")
        return build_response(500, {'message': 'Failed to update item'})

 # DELETE - CRUD   
def delete_item(path_params):
    if path_params is None or 'id' not in path_params:
        return build_response(400, {'message': 'Missing item ID'})
    
    item_id = path_params['id']
    
    # We don't typically check if the item exists before deleting, just attempt the delete
    table.delete_item(Key={'id': item_id})
    
    return build_response(204, None) # 204 means 'No Content' (successful deletion)

def lambda_handler(event, context):
    try:
        # Extract key routing parameters from the API Gateway event
        http_method = event.get('httpMethod')
        path = event.get('path')
        path_params = event.get('pathParameters')
        body = event.get('body')

        # --- Request Routing Logic ---
        
        # 1. DELETE /items/{id}
        if http_method == 'DELETE':
            return delete_item(path_params)
            
        # 2. GET /items/{id}
        if http_method == 'GET' and path_params:
            return get_item(path_params)
            
        # 3. POST /items (no ID in path)
        if http_method == 'POST':
            return create_item(body)
            
        # 4. PUT/PATCH /items/{id}
        if http_method in ['PUT', 'PATCH']:
            return update_item(path_params, body)
            
        # 5. GET /items (get all)
        if http_method == 'GET' and path == '/items':
            return get_all_items()
            
        # Fallback for unhandled methods/paths
        return build_response(405, {'message': 'Method or path not supported'})

    except Exception as e:
        print(f"FATAL ERROR: {e}")
        return build_response(500, {'message': 'Internal Server Error'})