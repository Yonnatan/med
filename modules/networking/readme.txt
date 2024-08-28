Lambda Function
  |
  v
NAT Gatway
  |
  v
WWW

VPC was created with two Subnets (Public+Private)
Nat Gateway attached to the Public Subnets
Lambda created on the Public Subnet (With both execution and vpc roles)


Task 3 (Networking) : 
Code - Find in networking Module (Code Comments are in /networking/main.tf)
Setup 
1) Clone the repo 
2) Terraform Init
Usage 
The module blocks in the root main.tf are conditioned so you can 
1) go to variables.tf set the default value of the apply_networking variable to "true" , Save and run terraform apply. 
2) Just use terraform apply -var="apply_networking=true"  to overwrite the default value. 

Validation from my side : 
1) EXECUTION
Tested in Lambda Dashboard 
2) LOGGING 
Log group created in cloudwatch