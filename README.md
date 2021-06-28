
# Scanning Legacy Documents with AWS Textract

### Process
This will set up two SQS queues and two correpsonding lambda functions to process their items.

`send_pdfs_to_textract_queue`  
Items in this queue reprsent PDFs in existing the `pdf_document_bucket` bucket defined in `terraform.tfvars`. The body of these items should be the filename (without the bucket path) of the document. This is probably the DocketEntryId. Additionally, you can define a message attribute, `docket_number` as a string value. If defined this will be added to the JSON document of the final file. 

`textract_complete_queue`  
This queue will automatically be populated by items from the SNS message topic, `textract_notification_topic`. Textract sends messages to `textract_notification_topic` when the asynchronous processing of the PDF has completed. You should not need to manually send items to this queue. 

After the process is finished documents are places in the `efcms-textract-result-documents` bucket created by terraform.

### Installing
AWS resources are managed by Terraform. From within the `terraform` directory, running the following should work as expected:

`terraform init` initialize  

then  

`terraform plan` see what's going to happen  
`terraform apply` push changes to AWS
`terraform destroy` pull it down. 

### Making it do something
Adding items to the `send_pdfs_to_textract_queue` will kick off the process. 
