provider "aws" {
  region = var.region
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name = var.app_name
  cidr = var.vpc_cidr

  azs             = ["${var.region}a", "${var.region}b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

resource "aws_ecr_repository" "app" {
  name = var.app_name
  force_delete = true # Ensures the repo is deleted even if images exist
  lifecycle {
    prevent_destroy = false
  }
}

resource "null_resource" "docker_build_push" {
  provisioner "local-exec" {
    command     = <<EOT
aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${aws_ecr_repository.app.repository_url}
docker build -t ${var.app_name} ../app
docker tag ${var.app_name}:latest ${aws_ecr_repository.app.repository_url}:latest
docker push ${aws_ecr_repository.app.repository_url}:latest
EOT
    interpreter = ["bash", "-c"]
  }

  triggers = {
    image_version = filemd5("../app/app.py")
  }
}

data "aws_ecr_image" "lambda_image" {
  repository_name = aws_ecr_repository.app.name
  image_tag       = "latest"

  depends_on = [null_resource.docker_build_push]
}

resource "aws_iam_role" "lambda_exec" {
  name = "${var.app_name}-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}


resource "aws_security_group" "lambda_sg" {
  name        = "${var.app_name}-sg"
  description = "Lambda security group"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_lambda_function" "app" {
  function_name = var.app_name
  package_type  = "Image"
  role          = aws_iam_role.lambda_exec.arn
  image_uri     = data.aws_ecr_image.lambda_image.image_uri
  timeout       = 30
  lifecycle {
    create_before_destroy = true
  }

  vpc_config {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  depends_on = [
    data.aws_ecr_image.lambda_image,
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_vpc_access
  ]
}

resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.app_name}-http-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.app.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.app.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}
