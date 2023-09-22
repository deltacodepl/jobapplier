provider "aws" {
  region = "eu-central-1"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.63.0"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }

  required_version = "~> 1.0"
}

locals {
  database_name = "jobsdb"
}

# AWS SQS
resource "aws_sqs_queue" "jobsearch_sqs" {
  name = "jobsearch"

  message_retention_seconds = 86400 # a day
}

# AWS IAM FOR jobsearch
module "jobsearch_iam_role" {
  source  = "mineiros-io/iam-role/aws"
  version = "~> 0.6.0"

  name = "jobsearch-role"

  assume_role_principals = [
    {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  ]
}

data "aws_iam_policy_document" "jobsearch_iam_policy" {
  statement {
    sid       = "AllowSQSPermissions"
    effect    = "Allow"
    resources = [aws_sqs_queue.jobsearch_sqs.arn]

    actions = [
      "sqs:ListQueues",
      "sqs:ListQueueTags",
      "sqs:GetQueueUrl",
      "sqs:SendMessage",
      "sqs:GetQueueAttributes",
      "sqs:ChangeMessageVisibility",
    ]
  }
}

resource "aws_iam_policy" "jobsearch_iam_policy" {
  policy = data.aws_iam_policy_document.jobsearch_iam_policy.json
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  policy_arn = aws_iam_policy.jobsearch_iam_policy.arn
  role       = module.jobsearch_iam_role.role.name
}

# AWS LAMBDA FOR jobsearch
resource "null_resource" "jobsearch_lambda_build" {
  triggers = {
    handler      = base64sha256(file("${path.module}/jobsearch/jobsearch/main.py"))
    requirements = base64sha256(file("${path.module}/jobsearch/requirements.txt"))
    build        = base64sha256(file("${path.module}/jobsearch/build.py"))
  }

  provisioner "local-exec" {
    command = "python ${path.module}/jobsearch/build.py"
  }
}

data "archive_file" "jobsearch_lambda_dependencies" {
  type        = "zip"
  source_dir  = "${path.module}/jobsearch/jobsearch/"
  output_path = "${path.module}/jobsearch/lambda.zip"

  depends_on = [null_resource.jobsearch_lambda_build]
}


module "jobsearch_lambda" {
  source  = "mineiros-io/lambda-function/aws"
  version = "~> 0.5.0"

  function_name    = "rent-search"
  description      = "Search ."
  filename         = data.archive_file.jobsearch_lambda_dependencies.output_path
  runtime          = "python3.8"
  handler          = "main.lambda_handler"
  timeout          = 60
  memory_size      = 128
  source_code_hash = data.archive_file.jobsearch_lambda_dependencies.output_base64sha256

  role_arn = module.jobsearch_iam_role.role.arn

  environment_variables = {
    "sqsname" = aws_sqs_queue.jobsearch_sqs.name
  }
}

# CloudWatch Event for rent-search
resource "aws_cloudwatch_event_rule" "every_day_at_eighteen" {
  name                = "every-day-at-18"
  description         = "Fires everyday at 18:00"
  schedule_expression = "cron(0 18 * * ? *)"
}

resource "aws_cloudwatch_event_target" "run_jobsearch_every_day_at_eighteen" {
  rule      = aws_cloudwatch_event_rule.every_day_at_eighteen.name
  target_id = "jobsearch_lambda"
  arn       = module.jobsearch_lambda.function.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_run_jobsearch_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = module.jobsearch_lambda.function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_day_at_eighteen.arn
}

#
resource "random_string" "db_gen_password" {
  length  = 34
  special = false
}

# AWS IAM
module "jobextract_iam_role" {
  source  = "mineiros-io/iam-role/aws"
  version = "~> 0.6.0"

  name = "jobextact-role"

  assume_role_principals = [
    {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  ]
}

data "aws_iam_policy_document" "jobextract_iam_policy" {
  statement {
    sid       = "AllowSQSPermissions"
    effect    = "Allow"
    resources = [aws_sqs_queue.jobsearch_sqs.arn]

    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage",
    ]
  }

  statement {
    sid       = "RDSDataServiceAccess"
    effect    = "Allow"
    resources = [aws_rds_cluster.aurora_serverless_mysql.arn]

    actions = [
      "rds-data:BatchExecuteStatement",
      "rds-data:BeginTransaction",
      "rds-data:CommitTransaction",
      "rds-data:ExecuteStatement",
      "rds-data:RollbackTransaction"
    ]
  }

  statement {
    sid       = "SecretsManagerDbCredentialsAccess"
    effect    = "Allow"
    resources = [aws_secretsmanager_secret.rds_credentials.arn]

    actions = [
      "secretsmanager:GetSecretValue",
    ]
  }

  statement {
    sid       = "AllowCreatingLogGroups"
    effect    = "Allow"
    resources = ["arn:aws:logs:eu-west-1:*:*"]
    actions   = ["logs:CreateLogGroup"]
  }

  statement {
    sid       = "AllowWritingLogs"
    effect    = "Allow"
    resources = ["arn:aws:logs:eu-west-1:*:log-group:/aws/lambda/*:*"]

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }
}

resource "aws_iam_policy" "jobextract_iam_policy" {
  policy = data.aws_iam_policy_document.jobextract_iam_policy.json
}

resource "aws_iam_role_policy_attachment" "jobextract_attach_policy" {
  policy_arn = aws_iam_policy.jobextract_iam_policy.arn
  role       = module.jobextract_iam_role.role.name
}

# AWS LAMBDA FOR jobEXTRACT
resource "null_resource" "jobextract_lambda_build" {
  triggers = {
    handler      = base64sha256(file("${path.module}/jobextract/jobextract/main.py"))
    requirements = base64sha256(file("${path.module}/jobextract/requirements.txt"))
    build        = base64sha256(file("${path.module}/jobextract/build.py"))
  }

  provisioner "local-exec" {
    command = "python ${path.module}/jobextract/build.py"
  }
}

data "archive_file" "jobextract_lambda_dependencies" {
  type        = "zip"
  source_dir  = "${path.module}/jobextract/jobextract/"
  output_path = "${path.module}/jobextract/lambda.zip"

  depends_on = [null_resource.jobextract_lambda_build]
}


module "jobextract_lambda" {
  source  = "mineiros-io/lambda-function/aws"
  version = "~> 0.5.0"

  function_name    = "job-extract"
  description      = "Extract property informations from SQS."
  filename         = data.archive_file.jobextract_lambda_dependencies.output_path
  runtime          = "python3.8"
  handler          = "main.lambda_handler"
  timeout          = 30
  memory_size      = 128
  source_code_hash = data.archive_file.jobextract_lambda_dependencies.output_base64sha256

  role_arn = module.jobextract_iam_role.role.arn

  environment_variables = {
    "clusterarn" = aws_rds_cluster.aurora_serverless_mysql.arn,
    "secretarn"  = aws_secretsmanager_secret_version.serverless_rds_credentials.arn
    "database"   = local.database_name,
  }
}

# AWS EVENT SOURCE MAPPING FOR jobEXTRACT
resource "aws_lambda_event_source_mapping" "event_source_mapping" {
  batch_size       = 1
  event_source_arn = aws_sqs_queue.jobsearch_sqs.arn
  enabled          = true
  function_name    = module.jobextract_lambda.function.arn
}
