VPC+ Subnets reused from Networking Module
Created RDS Instance (PostgreSQL)
Created Secret Manager Entry to manage SQL User
Created Lambda to :
1) Set up the DB
2) Create some Data
3) Create Two Users 
4) Use the users to test Multi-Tenancy + RLS

Task 4 (database) : 
Code - Find in networking Module (Code Comments are in /database/main.tf)
Setup 
1) Clone the repo 
2) Terraform Init
Usage 
##Note that due to the dependancy of the database module on resources created by the networking module, it will also be executed##
1) go to variables.tf set the default valu apply_database variables to "true" , Save and run terraform apply. 
2) Just use "terraform apply -var="apply_database=true"  to overwrite the default value. 


Validation from my side : 
1) EXECUTION
Tested in Lambda Dashboard 
2) LOGGING 
Log group created in cloudwatch