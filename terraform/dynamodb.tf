resource "aws_dynamodb_table" "data-linking-table" {
  name           = "textract-completed-ocr-efcms"
  billing_mode = "PAY_PER_REQUEST"
  read_capacity  = 20
  hash_key       = "docket_number"
  range_key      = "docket_entry_id"

  attribute {
    name = "docket_number"
    type = "S"
  }

  attribute {
    name = "docket_entry_id"
    type = "S"
  }
}