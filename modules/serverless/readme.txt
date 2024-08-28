User
  |
  v
API Gateway
  |
  v
Lambda Function
  |
  v
DynamoDB
  |
  v
Lambda Function
  |
  v
API Gateway
  |
  v
User


User sends requests to the API Gateway.
API Gateway forwards requests to the Lambda Function.
Lambda Function interacts with DynamoDB to perform database operations.
Lambda Function sends responses back to API Gateway, which then sends the response to the User.



Task 1 (Standalone) : 
Code - Find in Serverless Module (Code Comments are in /serverless/main.tf)
Setup 
1) Clone the repo 
2) Terraform Init
Usage 
The module blocks in the root main.tf are conditioned so you can 
1) go to variables.tf set the default value of the apply_serverless variable to "true" , Save and run terraform apply. 
2) Just use terraform apply -var="apply_serverless=true"  to overwrite the default value. 

Validation from my side : 
1) EXECUTION Eamples
B:\Academic\Repos\med>curl -X POST https://qqoyvsjdm4.execute-api.eu-west-1.amazonaws.com/prod/items -H "Content-Type: application/json" -d "{\"ItemId\": \"123\", \"Name\": \"Test Item\"}"
{"ItemId": "123", "Name": "Test Item"}
B:\Academic\Repos\med>curl -X GET https://qqoyvsjdm4.execute-api.eu-west-1.amazonaws.com/prod/items/123
{"ItemId": "123", "Name": "Test Item"}
B:\Academic\Repos\med>curl -X DELETE https://qqoyvsjdm4.execute-api.eu-west-1.amazonaws.com/prod/items/123

B:\Academic\Repos\med>curl -X GET https://qqoyvsjdm4.execute-api.eu-west-1.amazonaws.com/prod/items/123    
{"error": "Item not found"}
B:\Academic\Repos\med>
2) LOGGING 
Log groups created in cloudwatch (For both Lambda and ApiGW).