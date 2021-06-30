resource "aws_iam_role" "lambda_service_role" {
	name = "aws_lambda_service_role"
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
	name        = "aws_lambda_service_role_policy"
	description = "Write permissions for CloudWatch, SQS, textract, DDB, and s3"
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
				"textract:*",
				"dynamodb:*",
				"s3:*"
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

data "archive_file" "process_textract_notification" {
	type        = "zip"
	source_dir = "../lambda/process_textract_notice"
	output_path = "../lambda/zipfiles/process_textract_notice.zip"
}

data "archive_file" "process_pdf" {
	type        = "zip"
	source_dir = "../lambda/process_pdf"
	output_path = "../lambda/zipfiles/process_pdf.zip"
}


resource "aws_lambda_function" "process_pdf" {
	description      = "Send pdf to Textract"
    function_name    = "send-pdf-textract"
	filename         = data.archive_file.process_pdf.output_path
	source_code_hash = filebase64sha256(data.archive_file.process_pdf.output_path)

	role    = aws_iam_role.lambda_service_role.arn
	handler = "index.handler"
	runtime = "python3.8"

	depends_on = [
		aws_iam_role_policy_attachment.lambda_policy_attachment,
	]

	environment {
		variables = {
			SNS_TOPIC_ARN=aws_sns_topic.textract_notification_topic.arn,
            SNS_ROLE_ARN=aws_iam_role.textract_service_role.arn
            PDF_BUCKET=var.pdf_document_bucket
		}
	}
}

resource "aws_lambda_function" "get_text" {
	description      = "Process text after Textract is done"
    function_name    = "process-textract-notification"
	filename         = data.archive_file.process_textract_notification.output_path
	source_code_hash = filebase64sha256(data.archive_file.process_textract_notification.output_path)
    timeout          = 900
	role    = aws_iam_role.lambda_service_role.arn
	handler = "index.handler"
	runtime = "python3.8"

	depends_on = [
		aws_iam_role_policy_attachment.lambda_policy_attachment,
	]

	environment {
		variables = {
			SNS_TOPIC_ARN=aws_sns_topic.textract_notification_topic.arn,
            SNS_ROLE_ARN=aws_iam_role.textract_service_role.arn
            PDF_BUCKET=aws_s3_bucket.textract_results.id
            DYNAMODB_TABLE=aws_dynamodb_table.data-linking-table.name
		}
	}
}

resource "aws_lambda_event_source_mapping" "lambda_listens_for_textract_results" {
  event_source_arn = aws_sqs_queue.textract_complete_queue.arn
  function_name    = aws_lambda_function.get_text.arn
}

resource "aws_lambda_event_source_mapping" "lambda_process_pdfs" {
  event_source_arn = aws_sqs_queue.send_pdfs_to_textract_queue.arn
  function_name    = aws_lambda_function.process_pdf.arn
}
