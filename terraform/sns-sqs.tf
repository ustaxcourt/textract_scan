# This SNS topic recieves notifications when Textract has finished processing
# a job. An SQS queue will be setup to subscribe to this topic per:
# https://docs.aws.amazon.com/textract/latest/dg/async-analyzing-with-sqs.html

resource "aws_sns_topic" "textract_notification_topic" {
  name = "textract_notification_topic"
  delivery_policy = <<EOF
{
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultThrottlePolicy": {
      "maxReceivesPerSecond": 1
    }
  }
}
EOF
}

# SQS Queue to add PDF filenames to in order to kick off processing
resource "aws_sqs_queue" "send_pdfs_to_textract_queue_DQL" {
  name                       = "send_pdfs_to_textract_queue_DQL"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 1209600  # 14 days
}

resource "aws_sqs_queue" "send_pdfs_to_textract_queue" {
  name                       = "send_pdfs_to_textract_queue"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 1209600
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.send_pdfs_to_textract_queue_DQL.arn
    maxReceiveCount     = 4
  })
}

# SQS Queue to listen to SNS topic when textract jobs are done
resource "aws_sqs_queue" "textract_complete_queue_DQL" {
  name                       = "textract_complete_queue_DQL"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 1209600  # 14 days
}

resource "aws_sqs_queue" "textract_complete_queue" {
  name                       = "textract_complete_queue"
  visibility_timeout_seconds = 900
  message_retention_seconds  = 1209600 
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.textract_complete_queue_DQL.arn
    maxReceiveCount     = 4
  })
}

# AWS SQS Queue policy
resource "aws_sqs_queue_policy" "textract_complete_queue" {
  queue_url             =  aws_sqs_queue.textract_complete_queue.id
  policy                = <<POLICY
{
  "Version" : "2012-10-17",
  "Id" : "sqspolicy",
  "Statement" : [
    {
      "Sid" : "First",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:*",
      "Resource": "${aws_sqs_queue.textract_complete_queue.arn}"
    }
  ]   
}
POLICY
}

# Subsrcibe SQS to SNS topic
resource "aws_sns_topic_subscription" "textract_notification_topic_subscription" {
  topic_arn = aws_sns_topic.textract_notification_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.textract_complete_queue.arn
}


# Textract IAM Role and Policy
resource "aws_iam_role" "textract_service_role" {
	name = "aws_textract_service_role"
	assume_role_policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Principal": {
				"Service": "textract.amazonaws.com"
			},
			"Action": "sts:AssumeRole"
		}
	]
}
EOF
}

resource "aws_iam_policy" "textract_service_role_policy" {
	name        = "aws_textract_service_role_policy"
	description = "Allow access to SNS"
	path        = "/"
	policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "",
			"Effect": "Allow",
			"Action": [
				"sns:*"
			],
			"Resource": "*"
		}
	]
}
EOF
}

resource "aws_iam_role_policy_attachment" "textract_policy_attachment" {
	role       = aws_iam_role.textract_service_role.name
	policy_arn = aws_iam_policy.textract_service_role_policy.arn
}