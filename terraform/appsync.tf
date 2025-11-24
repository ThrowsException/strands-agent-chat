resource "aws_appsync_graphql_api" "chat_api" {
  name                = "chat-api"
  authentication_type = "API_KEY"

  schema = <<EOF
type Message {
  id: ID!
  content: String!
  sender: String!
  sessionId: String!
  timestamp: AWSDateTime!
}

type ChatResponse {
  sessionId: String!
  message: String!
  response: String!
  timestamp: AWSDateTime!
}

type Mutation {
  sendMessage(content: String!, sender: String!, sessionId: String!): Message
  chat(message: String!, sessionId: String): ChatResponse
}

type Subscription {
  onMessageReceived(sessionId: String!): Message
    @aws_subscribe(mutations: ["sendMessage"])
  onChatResponse(sessionId: String!): ChatResponse
    @aws_subscribe(mutations: ["chat"])
}

type Query {
  getMessage(id: ID!): Message
  getSession(sessionId: String!): ChatResponse
}

schema {
  query: Query
  mutation: Mutation
  subscription: Subscription
}
EOF

  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_logs.arn
    field_log_level          = "ERROR"
  }
}

resource "aws_appsync_api_key" "chat_api_key" {
  api_id  = aws_appsync_graphql_api.chat_api.id
  expires = timeadd(timestamp(), "72h")
}

resource "aws_appsync_datasource" "lambda_datasource" {
  api_id           = aws_appsync_graphql_api.chat_api.id
  name             = "lambda_datasource"
  service_role_arn = aws_iam_role.appsync_lambda.arn
  type             = "AWS_LAMBDA"

  lambda_config {
    function_arn = aws_lambda_function.chat_handler.arn
  }
}

resource "aws_appsync_resolver" "send_message_resolver" {
  api_id      = aws_appsync_graphql_api.chat_api.id
  type        = "Mutation"
  field       = "sendMessage"
  data_source = aws_appsync_datasource.lambda_datasource.name

  request_template = <<EOF
{
  "version": "2017-02-28",
  "operation": "Invoke",
  "payload": {
    "field": "sendMessage",
    "arguments": $utils.toJson($context.arguments)
  }
}
EOF

  response_template = <<EOF
$utils.toJson($context.result)
EOF
}

resource "aws_iam_role" "appsync_lambda" {
  name = "appsync-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "appsync.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "appsync_lambda_policy" {
  name = "appsync-lambda-policy"
  role = aws_iam_role.appsync_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "lambda:InvokeFunction"
        ]
        Effect   = "Allow"
        Resource = [
          aws_lambda_function.chat_handler.arn,
          aws_lambda_function.strands_agent_handler.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role" "appsync_logs" {
  name = "appsync-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "appsync.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "appsync_logs_policy" {
  role       = aws_iam_role.appsync_logs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppSyncPushToCloudWatchLogs"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "chat_handler" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "chat-message-handler"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout = 30

  environment {
    variables = {
      APPSYNC_API_ENDPOINT = aws_appsync_graphql_api.chat_api.uris["GRAPHQL"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda-exec-role"

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

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_bedrock_policy" {
  name = "lambda-bedrock-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "bedrock:InvokeModel"
        ]
        Effect = "Allow"
        Resource = [
          # "arn:aws:bedrock:us-east-1::foundation-model/amazon.nova-micro-v1:0",
          # "arn:aws:bedrock:us-east-2::foundation-model/amazon.nova-micro-v1:0",
          # "arn:aws:bedrock:*:063754174791:inference-profile/us.amazon.nova-micro-v1:0"
          "*"
        ]
      }
    ]
  })
}

output "appsync_api_url" {
  value = aws_appsync_graphql_api.chat_api.uris["GRAPHQL"]
}

output "appsync_api_key" {
  value     = aws_appsync_api_key.chat_api_key.key
  sensitive = true
}
