import json
import os
import urllib.request
import urllib.parse
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info(f"Event: {json.dumps(event)}")
    
    # Get the API endpoint from environment variables
    api_endpoint = os.environ.get('API_ENDPOINT_PAYMENT')
    
    if not api_endpoint:
        logger.error("API_ENDPOINT_PAYMENT environment variable not set")
        return {
            'statusCode': 500,
            'body': json.dumps('API endpoint not configured')
        }
    
    try:
        # Extract order data from the event
        input_data = event.get('Payload', {})
        order_id = input_data.get('orderId')
        
        # Prepare the request data
        payment_request = {
            'orderId': order_id,
            'amount': input_data.get('body', {}).get('amount', 0),
            'customerId': input_data.get('body', {}).get('customerId')
        }
        
        data = json.dumps(payment_request).encode('utf-8')
        
        # Create the request
        req = urllib.request.Request(
            f"{api_endpoint}/process",
            data=data,
            headers={'Content-Type': 'application/json'}
        )
        
        # Send the request to the payment service
        logger.info(f"Sending request to {api_endpoint}/process")
        with urllib.request.urlopen(req) as response:
            response_body = response.read()
            logger.info(f"Response: {response_body}")
            
            # Parse the response
            response_data = json.loads(response_body)
            
            # Return the response
            return {
                'statusCode': response.getcode(),
                'body': response_data,
                'orderId': order_id
            }
    
    except urllib.error.HTTPError as e:
        logger.error(f"HTTPError: {e.code} - {e.reason}")
        return {
            'statusCode': e.code,
            'body': e.reason,
            'orderId': input_data.get('orderId')
        }
    
    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': str(e),
            'orderId': input_data.get('orderId')
        }