terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
}
provider "aws" {
  profile = "default"
  region  = "eu-central-1"
}

variable "myregion" {
  type = string
  default = "eu-central-1"
}

variable "functions" {
  description = "List of functions to be created"
  type = list(string)
  default = ["SLW-empty-SQS-terraform", "SLW-poll-from-SQS-terraform", "SLW-put-into-SQS-terraform"]
}

# Pulling out account information

data "aws_caller_identity" "current" {}

# Pulling information from my already existant hosted zone on route53 for later use

data "aws_route53_zone" "abugharbia" {
  name         = "abugharbia.com"
  private_zone = false
}

# Creating zip files from my lambda functions

data "archive_file" "lambda_functions" {
  count = length(var.functions)
  type = "zip"
  source_file = "${var.functions[count.index]}.py"
  output_path = "${var.functions[count.index]}.zip"
}

# Creation of 3 lambda functions

resource "aws_lambda_function" "SLW_functions" {
  count = length(var.functions)
  function_name = var.functions[count.index]
  role = aws_iam_role.SLW_lambda_functions_iam[count.index].arn
  handler = "${var.functions[count.index]}.lambda_handler"
  filename = "${var.functions[count.index]}.zip"
  source_code_hash = data.archive_file.lambda_functions[count.index].output_base64sha256
  runtime = "python3.8"
}

# Creation of an SQS queue (Simple Queueing Service)

resource "aws_sqs_queue" "SLW_Queue_terraform" {
  name = "SLW-queue-terraform"
  delay_seconds = 0
  max_message_size = 262144
  visibility_timeout_seconds = 5
  message_retention_seconds = 1209600
}

# Definition of the access policy for my SQS queue, so that the lambda functions have access to the queue.

resource "aws_sqs_queue_policy" "SLW_queue_terraform_access_policy" {
  queue_url = aws_sqs_queue.SLW_Queue_terraform.id

  policy = <<POLICY
{
  "Id": "Policy1619610917609",
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1619610800094",
      "Action": "sqs:*",
      "Effect": "Allow",
      "Resource": "${aws_sqs_queue.SLW_Queue_terraform.arn}",
      "Principal": {
        "AWS": [
          "${aws_iam_role.SLW_lambda_functions_iam[0].arn}"
        ]
      }
    },
    {
      "Sid": "Stmt1619610877056",
      "Action": [
        "sqs:ReceiveMessage"
      ],
      "Effect": "Allow",
      "Resource": "${aws_sqs_queue.SLW_Queue_terraform.arn}",
      "Principal": {
        "AWS": [
          "${aws_iam_role.SLW_lambda_functions_iam[1].arn}"
        ]
      }
    },
    {
      "Sid": "Stmt1619610912769",
      "Action": [
        "sqs:SendMessage"
      ],
      "Effect": "Allow",
      "Resource": "${aws_sqs_queue.SLW_Queue_terraform.arn}",
      "Principal": {
        "AWS": [
          "${aws_iam_role.SLW_lambda_functions_iam[2].arn}"
        ]
      }
    }
  ]
}
POLICY
}

# Creation of an API-Gateway as REST API

resource "aws_api_gateway_rest_api" "SLW_API_terraform" {
  name = "SLW-API-terraform"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# Creation of 3 resources on my API for the 3 lambda functions

resource "aws_api_gateway_resource" "SLW_API_terraform_resource" {
  count = length(var.functions)
  parent_id   = aws_api_gateway_rest_api.SLW_API_terraform.root_resource_id
  path_part   = var.functions[count.index]
  rest_api_id = aws_api_gateway_rest_api.SLW_API_terraform.id
}

# Creation of 3 GET Methods for the 3 resources created above

resource "aws_api_gateway_method" "SLW_API_terraform_method" {
  count = length(var.functions)
  authorization = "NONE"
  http_method   = "GET"
  resource_id   = aws_api_gateway_resource.SLW_API_terraform_resource[count.index].id
  rest_api_id   = aws_api_gateway_rest_api.SLW_API_terraform.id
}

# Integration of the method to invoke the corresponding lambda function

resource "aws_api_gateway_integration" "integrations" {
  count = length(var.functions)
  rest_api_id             = aws_api_gateway_rest_api.SLW_API_terraform.id
  resource_id             = aws_api_gateway_resource.SLW_API_terraform_resource[count.index].id
  http_method             = aws_api_gateway_method.SLW_API_terraform_method[count.index].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.SLW_functions[count.index].invoke_arn
}

# Altering the lambda function permissions to allow an invoke from the API-Gateway

resource "aws_lambda_permission" "lambda_permissions" {
  count = length(var.functions)
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.SLW_functions[count.index].function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.myregion}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.SLW_API_terraform.id}/*/${aws_api_gateway_method.SLW_API_terraform_method[count.index].http_method}${aws_api_gateway_resource.SLW_API_terraform_resource[count.index].path}"
}

# Deploying the API-Gateway

resource "aws_api_gateway_deployment" "SLW_API_terraform_deployment" {
  rest_api_id = aws_api_gateway_rest_api.SLW_API_terraform.id
  lifecycle {
    create_before_destroy = true
  }
}

# Identifying the stage in which the API will be deployed (prod)

resource "aws_api_gateway_stage" "SLW_API_terraform_stage" {
  deployment_id = aws_api_gateway_deployment.SLW_API_terraform_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.SLW_API_terraform.id
  stage_name    = "prod"
}

# Attaching a costum domain name to the API

resource "aws_api_gateway_domain_name" "SLW_API_Domain_Name" {
  domain_name = "api.abugharbia.com"
  regional_certificate_arn = aws_acm_certificate_validation.API_Gateway.certificate_arn
  security_policy = "TLS_1_2"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# Creating a Route53 record, to route traffic from the costum domain name to the API

resource "aws_route53_record" "SLW_API_Domain_Name_Route53_Record" {
  name    = aws_api_gateway_domain_name.SLW_API_Domain_Name.domain_name
  type    = "A"
  zone_id = data.aws_route53_zone.abugharbia.id

  alias {
    evaluate_target_health = true
    name                   = aws_api_gateway_domain_name.SLW_API_Domain_Name.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.SLW_API_Domain_Name.regional_zone_id
  }
}

# Mapping to where the traffic should be routed to within the API

resource "aws_api_gateway_base_path_mapping" "SLW_API_Mapping" {
  api_id      = aws_api_gateway_rest_api.SLW_API_terraform.id
  stage_name  = aws_api_gateway_stage.SLW_API_terraform_stage.stage_name
  domain_name = aws_api_gateway_domain_name.SLW_API_Domain_Name.domain_name
  base_path   = aws_api_gateway_stage.SLW_API_terraform_stage.stage_name
}