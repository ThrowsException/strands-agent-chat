# S3 bucket for Strands agent chat history
resource "aws_s3_bucket" "strands_chat_history" {
  bucket_prefix = "strands-agent-chat-history-"
}

resource "aws_s3_bucket_versioning" "strands_chat_history" {
  bucket = aws_s3_bucket.strands_chat_history.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Build Lambda deployment package with dependencies
resource "null_resource" "build_strands_dependencies" {
  triggers = {
    requirements = filemd5("${path.module}/../agent/pyproject.toml")
    code         = filemd5("${path.module}/../agent/main.py")
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/../agent"
    command = <<-EOT
      mkdir -p .build
      uv export --frozen --no-dev --no-editable -o requirements.txt
      uv pip install \
        --no-installer-metadata \
        --no-compile-bytecode \
        --python-platform x86_64-manylinux2014 \
        --python 3.11 \
        --target .build \
        -r requirements.txt
      cp main.py .build/
    EOT
  }
}

# Lambda deployment package (function code + dependencies)
data "archive_file" "strands_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../agent/.build"
  output_path = "${path.module}/strands_lambda.zip"

  depends_on = [null_resource.build_strands_dependencies]
}

resource "aws_lambda_function" "strands_agent_handler" {
  filename         = data.archive_file.strands_lambda_zip.output_path
  function_name    = "strands-agent-chat-handler"
  role             = aws_iam_role.strands_lambda_exec.arn
  handler          = "main.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.strands_lambda_zip.output_base64sha256
  timeout          = 60
  memory_size      = 512

  environment {
    variables = {
      S3_BUCKET_NAME = aws_s3_bucket.strands_chat_history.id
    }
  }
}

# IAM role for Lambda execution
resource "aws_iam_role" "strands_lambda_exec" {
  name = "strands-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "strands_lambda_basic" {
  role       = aws_iam_role.strands_lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "strands_lambda_permissions" {
  name = "strands-lambda-permissions"
  role = aws_iam_role.strands_lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Effect = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Effect = "Allow"
        Resource = "${aws_s3_bucket.strands_chat_history.arn}/*"
      },
      {
        Action = [
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = aws_s3_bucket.strands_chat_history.arn
      }
    ]
  })
}

# AppSync DataSource for Strands Lambda
resource "aws_appsync_datasource" "strands_lambda_datasource" {
  api_id           = aws_appsync_graphql_api.chat_api.id
  name             = "strands_lambda_datasource"
  service_role_arn = aws_iam_role.appsync_lambda.arn
  type             = "AWS_LAMBDA"

  lambda_config {
    function_arn = aws_lambda_function.strands_agent_handler.arn
  }
}

# AppSync Resolver for chat mutation
resource "aws_appsync_resolver" "strands_chat_resolver" {
  api_id      = aws_appsync_graphql_api.chat_api.id
  type        = "Mutation"
  field       = "chat"
  data_source = aws_appsync_datasource.strands_lambda_datasource.name

  request_template = <<EOF
{
  "version": "2017-02-28",
  "operation": "Invoke",
  "payload": {
    "arguments": $utils.toJson($context.arguments),
    "identity": $utils.toJson($context.identity)
  }
}
EOF

  response_template = <<EOF
$utils.toJson($context.result)
EOF
}

output "strands_s3_bucket" {
  value       = aws_s3_bucket.strands_chat_history.id
  description = "S3 bucket for Strands agent chat history"
}
