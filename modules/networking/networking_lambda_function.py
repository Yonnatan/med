import json
import http.client

def lambda_handler(event, context):
    try:
        # Test connectivity to an external service
        conn = http.client.HTTPConnection("www.google.com", timeout=10)
        conn.request("HEAD", "/")
        response = conn.getresponse()
        status_code = response.status
        conn.close()

        return {
            'statusCode': status_code,
            'body': json.dumps('Connectivity test successful!')
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }