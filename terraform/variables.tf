variable "aws_region" {
  type        = string
  description = "AWS Region"
}

variable "pdf_document_bucket" {
    type = string
    description = "The S3 Bucket where the PDF documents live"
}

variable "textract_results_bucket" {
    type = string
    description = "What to name the results bucket"
}