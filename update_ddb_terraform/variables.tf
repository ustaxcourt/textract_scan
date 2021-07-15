
variable "aws_region" {
  type        = string
  description = "AWS Region"
}

variable "ddb_destination_table_name" {
    type = string
    description = "The name of the table to write document contents to"
}
