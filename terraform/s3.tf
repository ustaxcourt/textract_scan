# S3 Bucket for Textract Results
resource "aws_s3_bucket" "textract_results" {
  bucket = "efcms-textract-result-documents"
  force_destroy = true
}

# S3 Bucket Policy
resource "aws_s3_bucket_policy" "textract_results" {
  bucket                = aws_s3_bucket.textract_results.id
  policy                = <<POLICY
{
  "Version" : "2012-10-17",
  "Id" : "",
  "Statement" : [
    {
      "Sid" : "First",
      "Effect": "Allow",
      "Action": "s3:*",
      "Principal": {
        "AWS": "${aws_iam_role.lambda_service_role.arn}"
      },
      "Resource": [
        "${aws_s3_bucket.textract_results.arn}"
      ]
    }
  ]   
}
POLICY
}