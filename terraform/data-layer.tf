# terraform/data-layer.tf
# DynamoDB, S3, SNS, SQS, and Lambda resources

# ==================== DYNAMODB ====================
resource "aws_dynamodb_table" "inspections" {
  name         = "${local.name_prefix}-inspections"
  billing_mode = "PAY_PER_REQUEST" # On-demand for cost savings
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "GSI1PK"
    type = "S"
  }

  attribute {
    name = "GSI1SK"
    type = "S"
  }

  global_secondary_index {
    name            = "GSI1"
    hash_key        = "GSI1PK"
    range_key       = "GSI1SK"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = { Name = "${local.name_prefix}-inspections-table" }
}

# ==================== S3 ====================
resource "aws_s3_bucket" "images" {
  bucket = "${local.name_prefix}-images-${data.aws_caller_identity.current.account_id}"
  tags   = { Name = "${local.name_prefix}-images" }
}

resource "aws_s3_bucket_versioning" "images" {
  bucket = aws_s3_bucket.images.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "images" {
  bucket = aws_s3_bucket.images.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "images" {
  bucket                  = aws_s3_bucket.images.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = ["*"] # Restrict in production
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# ==================== SNS ====================
resource "aws_sns_topic" "notifications" {
  name = "${local.name_prefix}-notifications"
  tags = { Name = "${local.name_prefix}-notifications-topic" }
}

# ==================== SQS ====================
resource "aws_sqs_queue" "notifications_dlq" {
  name                      = "${local.name_prefix}-notifications-dlq"
  message_retention_seconds = 1209600 # 14 days
  tags                      = { Name = "${local.name_prefix}-notifications-dlq" }
}

resource "aws_sqs_queue" "notifications" {
  name                       = "${local.name_prefix}-notifications"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400 # 1 day
  receive_wait_time_seconds  = 10    # Long polling

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notifications_dlq.arn
    maxReceiveCount     = 3
  })

  tags = { Name = "${local.name_prefix}-notifications-queue" }
}

resource "aws_sqs_queue_policy" "notifications" {
  queue_url = aws_sqs_queue.notifications.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "sns.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.notifications.arn
        Condition = {
          ArnEquals = { "aws:SourceArn" = aws_sns_topic.notifications.arn }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "notifications_sqs" {
  topic_arn = aws_sns_topic.notifications.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.notifications.arn
}

# ==================== LAMBDA ====================
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/sendNotification"
  output_path = "${path.module}/../lambda/sendNotification.zip"
}

resource "aws_lambda_function" "send_notification" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${local.name_prefix}-sendNotification"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = { Name = "${local.name_prefix}-sendNotification" }
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.notifications.arn
  function_name    = aws_lambda_function.send_notification.arn
  batch_size       = 10
  enabled          = true
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.send_notification.function_name}"
  retention_in_days = 14
}
