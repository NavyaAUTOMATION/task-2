# Task 2 - Fully Automated Serverless Container Deployment using Terraform

This Terraform project fully automates the deployment of a serverless container-based application on AWS.

### What it sets up:
- A VPC with public and private subnets
- An Amazon ECR repository
- A containerized Lambda function
- API Gateway (HTTP API) for public access
- Docker image build and push automated via Terraform (`null_resource`)

---

## Prerequisites

Ensure the following tools are installed on the system where you're running this

| Tool         | Required Version     |
|--------------|----------------------|
| Terraform    | ≥ 1.3.0              |
| AWS CLI      | ≥ 2.0                |
| Docker       | Desktop or Engine    |
| Git          | Any                  |

---

## Project Structure
task-2/
├── app/ # Python app source code with Dockerfile
│ ├── app.py
│ └── Dockerfile
├── terraform/
  ├── main.tf # All Terraform resources
  ├── variables.tf # Input variables
  ├── outputs.tf # Output values
  ├── terraform.tfvars # Variable values (region, app name, etc.)
├── .gitignore
└── README.md

git clone https://github.com/NavyaAUTOMATION/task-2.git
cd task-2
## Configure AWS Credentials
aws configure
Enter:
AWS Access Key ID
AWS Secret Access Key
Default region (use us-east-1)
Output format: json (or blank)

## Ensure Docker Daemon is Running
sudo systemctl start docker
Confirm Docker is working:
docker info
## Run Terraform to Build Infrastructure and Push Image
terraform init
terraform plan
terraform apply

 # Terraform will:
Authenticate to ECR
Build the container image (app/)
Tag and push it to ECR
Deploy it as a Lambda function
Attach the function to an API Gateway endpoint

When prompted, type yes.

# Output
After apply, Terraform will print the API Gateway endpoint URL. You can access your deployed app via that public URL.
example- "https://ozsz9y6ggi.execute-api.us-east-1.amazonaws.com/"

# To Destroy the Stack
terraform destroy


