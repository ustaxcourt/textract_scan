resource "aws_sqs_queue" "process_document_contents_queue_DQL" {
  name                       = "process_document_contents_queue_DQL"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 1209600  # 14 days
}

resource "aws_sqs_queue" "process_document_contents_queue" {
  name                       = "process_document_contents_queue"
  message_retention_seconds  = 1209600
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.process_document_contents_queue_DQL.arn
    maxReceiveCount     = 4
  })
}
