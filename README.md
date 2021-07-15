
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

# Reconcile DDB tables
The textract scanning process produced a DynamoDB table the holds the link between the JSON documents in S3 and the Docket-Entries in Dynamo. 

The terraform in `update_ddb_terraform` will deploy an SQS queue and subscribed Lambda Function that will update items in Dawson's DynamoDB table as items show up in the queue.

**To depoly:**

- set the terraform variable `ddb_destination_table_name` to the correct dynamo table
- ensure AWS credentials are available in your environment
- `> cd update_ddb_terraform`
- `> terraform init`
- `> terraform plan`
- assuming the above looks good
- `> terraform apply`

**To populate queue:**

The script in `scripts/send_document_contents_sqs.py` will read from the Dynamo table `textract-completed-ocr-efcms` set as `SOURCE_TABLE_NAME` in the script.

After confirming `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are set in the environment running, executing this script will start the process of scanning the source table and sending batches of SQS items to the queue. In migration, this took about 3.5 hours.

