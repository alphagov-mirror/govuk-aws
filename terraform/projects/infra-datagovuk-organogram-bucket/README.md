## Project: datagovuk-organogram-bucket

This creates an s3 bucket

datagovuk-organogram-bucket: A bucket to hold data.gov.uk organogram files

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| aws\_environment | AWS Environment | string | n/a | yes |
| aws\_region | AWS region | string | `"eu-west-1"` | no |
| domain | The domain of the data.gov.uk service to manage | string | n/a | yes |
| remote\_state\_bucket | S3 bucket we store our terraform state in | string | n/a | yes |
| remote\_state\_infra\_monitoring\_key\_stack | Override stackname path to infra_monitoring remote state | string | `""` | no |
| stackname | Stackname | string | n/a | yes |

