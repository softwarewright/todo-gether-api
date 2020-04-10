resource "aws_iam_role" "todo_api_role" {
  name = "TodoApiLambdaRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

provider "aws" {
  version = "~> 2.0"
  region = "us-west-2"
#   access_key                  = "mock_access_key"
#   s3_force_path_style         = true
#   secret_key                  = "mock_secret_key"
#   skip_credentials_validation = true
#   skip_metadata_api_check     = true
#   skip_requesting_account_id  = true

#   endpoints {
#     apigateway     = "http://localhost:4567"
#     cloudformation = "http://localhost:4581"
#     cloudwatch     = "http://localhost:4582"
#     dynamodb       = "http://localhost:4569"
#     es             = "http://localhost:4578"
#     firehose       = "http://localhost:4573"
#     iam            = "http://localhost:4593"
#     kinesis        = "http://localhost:4568"
#     lambda         = "http://localhost:4574"
#     route53        = "http://localhost:4580"
#     redshift       = "http://localhost:4577"
#     s3             = "http://localhost:4572"
#     secretsmanager = "http://localhost:4584"
#     ses            = "http://localhost:4579"
#     sns            = "http://localhost:4575"
#     sqs            = "http://localhost:4576"
#     ssm            = "http://localhost:4583"
#     stepfunctions  = "http://localhost:4585"
#     sts            = "http://localhost:4592"
#   }
}

data "archive_file" "lambda_source" {
    type = "zip"
    source_dir = "${path.module}/../dist"
    output_path = "${path.module}/lambda_code.zip"
}

data "aws_partition" "current" {}
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_api_gateway_rest_api" "api" {
    name = "todo_gether_api"
}

resource "aws_api_gateway_resource" "resource" {
    path_part = "resource"
    parent_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
    rest_api_id = "${aws_api_gateway_rest_api.api.id}"
}

resource "aws_api_gateway_method" "method" {
    rest_api_id = "${aws_api_gateway_rest_api.api.id}"
    resource_id = "${aws_api_gateway_resource.resource.id}"
    http_method = "ANY"
    authorization = "NONE"
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.resource.id}"
  http_method = "${aws_api_gateway_method.method.http_method}"
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = "${aws_lambda_function.lambda.invoke_arn}"
}

resource "aws_api_gateway_stage" "stage" {
    stage_name = "prod"
    rest_api_id = "${aws_api_gateway_rest_api.api.id}"
    deployment_id = "${aws_api_gateway_deployment.deployment.id}"
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [ "aws_api_gateway_integration.integration" ]
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  stage_name = "dev" 
}



# resource "aws_iam_policy" "invocation_role" {
#   name = "api_gateway_todo_gether_role"
#   path = "/"

#   policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Action": "sts:AssumeRole",
#       "Principal": {
#         "Service": "apigateway.amazonaws.com"
#       },
#       "Effect": "Allow",
#       "Sid": ""
#     }
#   ]
# }
# EOF
# }

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.lambda.function_name}"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.api.id}/*/*"
}

resource "aws_iam_role_policy" "invocation_policy" {
  name = "default"
  role = "${aws_iam_role.todo_api_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "lambda:InvokeFunction",
      "Effect": "Allow",
      "Resource": "${aws_lambda_function.lambda.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "lambda_logging" {
  name = "todo_lambda_role"
  description = "IAM policy for todo lambda permissions"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = "${aws_iam_role.todo_api_role.name}"
  policy_arn = "${aws_iam_policy.lambda_logging.arn}"
}

resource "aws_lambda_function" "lambda" {
    filename = "lambda_code.zip"
    function_name = "todo_gether_lambda"
    role = "${aws_iam_role.todo_api_role.arn}"
    handler = "index.handler"
    source_code_hash = "${data.archive_file.lambda_source.output_base64sha256}"
    runtime = "nodejs12.x"

    environment {
        variables = {
            env = "prod"
        }
    }
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
    name = "/aws/lambda/todo_gether_lambda"
    retention_in_days = 7
}