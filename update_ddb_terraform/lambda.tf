resource "aws_iam_role" "lambda_service_role" {
	name = "doc_contents_lambda_service_role"
	assume_role_policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Principal": {
				"Service": "lambda.amazonaws.com"
			},
			"Action": "sts:AssumeRole"
		}
	]
}
EOF
}

resource "aws_iam_policy" "lambda_service_role_policy" {
	name        = "doc_contents_lambda_service_role_policy"
	description = "Write permissions for CloudWatch, SQS, and DDB"
	path        = "/"
	policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "",
			"Effect": "Allow",
			"Action": [
				"lambda:*",
				"logs:*",
				"sqs:*",
				"dynamodb:*"
			],
			"Resource": "*"
		}
	]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
	role       = aws_iam_role.lambda_service_role.name
	policy_arn = aws_iam_policy.lambda_service_role_policy.arn
}

provider "archive" {}

data "archive_file" "copy_document_contents_id" {
	type        = "zip"
	source_dir = "../lambda/copy_document_contents_id"
	output_path = "../lambda/zipfiles/copy_document_contents_id.zip"
}

resource "aws_lambda_function" "copy_document_contents_id" {
	description      = "Processes SQS items and writes document contents id to dynamoDB"
    function_name    = "copy-document-contents-id"
	filename         = data.archive_file.copy_document_contents_id.output_path
	source_code_hash = filebase64sha256(data.archive_file.copy_document_contents_id.output_path)

	role    = aws_iam_role.lambda_service_role.arn
	handler = "index.handler"
	runtime = "python3.8"

	depends_on = [
		aws_iam_role_policy_attachment.lambda_policy_attachment,
	]

	environment {
		variables = {
            DESTINATION_TABLE_NAME=var.ddb_destination_table_name
		}
	}
}

resource "aws_lambda_event_source_mapping" "lambda_listens_for_document_contents" {
  event_source_arn = aws_sqs_queue.process_document_contents_queue.arn
  function_name    = aws_lambda_function.copy_document_contents_id.arn
}
