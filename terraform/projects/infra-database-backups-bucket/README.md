## Project: database-backups-bucket

This creates an s3 bucket

database-backups: The bucket that will hold database backups

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| aws\_backup\_region | AWS region | string | `"eu-west-2"` | no |
| aws\_environment | AWS Environment | string | n/a | yes |
| aws\_region | AWS region | string | `"eu-west-1"` | no |
| remote\_state\_bucket | S3 bucket we store our terraform state in | string | n/a | yes |
| remote\_state\_infra\_monitoring\_key\_stack | Override stackname path to infra_monitoring remote state | string | `""` | no |
| stackname | Stackname | string | n/a | yes |
| training\_and\_integration\_only | Only apply these policies to training or integration | string | `"false"` | no |

## Outputs

| Name | Description |
|------|-------------|
| content\_data\_api\_dbadmin\_write\_database\_backups\_bucket\_policy\_arn | ARN of the Content Data API DBAdmin database_backups bucket writer policy |
| dbadmin\_write\_database\_backups\_bucket\_policy\_arn | ARN of the DBAdmin write database_backups-bucket policy |
| elasticsearch\_write\_database\_backups\_bucket\_policy\_arn | ARN of the elasticsearch write database_backups-bucket policy |
| email-alert-api\_dbadmin\_write\_database\_backups\_bucket\_policy\_arn | ARN of the EmailAlertAPIDBAdmin write database_backups-bucket policy |
| graphite\_write\_database\_backups\_bucket\_policy\_arn | ARN of the Graphite write database_backups-bucket policy |
| integration\_dbadmin\_read\_database\_backups\_bucket\_policy\_arn | ARN of the integration read DBAdmin database_backups-bucket policy |
| integration\_elasticsearch\_read\_database\_backups\_bucket\_policy\_arn | ARN of the integration read elasticsearch database_backups-bucket policy |
| integration\_email-alert-api\_dbadmin\_read\_database\_backups\_bucket\_policy\_arn | ARN of the integration read EmailAlertAPUDBAdmin database_backups-bucket policy |
| integration\_graphite\_read\_database\_backups\_bucket\_policy\_arn | ARN of the integration read Graphite database_backups-bucket policy |
| integration\_mongo\_api\_read\_database\_backups\_bucket\_policy\_arn | ARN of the integration read mongo-api database_backups-bucket policy |
| integration\_mongo\_router\_read\_database\_backups\_bucket\_policy\_arn | ARN of the integration read router_backend database_backups-bucket policy |
| integration\_mongodb\_read\_database\_backups\_bucket\_policy\_arn | ARN of the integration read mongodb database_backups-bucket policy |
| integration\_publishing-api\_dbadmin\_read\_database\_backups\_bucket\_policy\_arn | ARN of the integration read publishing-apiDBAdmin database_backups-bucket policy |
| integration\_transition\_dbadmin\_read\_database\_backups\_bucket\_policy\_arn | ARN of the integration read TransitionDBAdmin database_backups-bucket policy |
| mongo\_api\_write\_database\_backups\_bucket\_policy\_arn | ARN of the mongo-api write database_backups-bucket policy |
| mongo\_router\_write\_database\_backups\_bucket\_policy\_arn | ARN of the router_backend write database_backups-bucket policy |
| mongodb\_write\_database\_backups\_bucket\_policy\_arn | ARN of the mongodb write database_backups-bucket policy |
| production\_content\_data\_api\_dbadmin\_read\_database\_backups\_bucket\_policy\_arn | ARN of the production database_backups bucket reader policy for the Content Data API |
| production\_dbadmin\_read\_database\_backups\_bucket\_policy\_arn | ARN of the production read DBAdmin database_backups-bucket policy |
| production\_elasticsearch\_read\_database\_backups\_bucket\_policy\_arn | ARN of the production read elasticsearch database_backups-bucket policy |
| production\_email-alert-api\_dbadmin\_read\_database\_backups\_bucket\_policy\_arn | ARN of the production read EmailAlertAPUDBAdmin database_backups-bucket policy |
| production\_graphite\_read\_database\_backups\_bucket\_policy\_arn | ARN of the production read Graphite database_backups-bucket policy |
| production\_mongo\_api\_read\_database\_backups\_bucket\_policy\_arn | ARN of the production read mongo-api database_backups-bucket policy |
| production\_mongo\_router\_read\_database\_backups\_bucket\_policy\_arn | ARN of the production read router_backend database_backups-bucket policy |
| production\_mongodb\_read\_database\_backups\_bucket\_policy\_arn | ARN of the production read mongodb database_backups-bucket policy |
| production\_publishing-api\_dbadmin\_read\_database\_backups\_bucket\_policy\_arn | ARN of the production read publishing-apiDBAdmin database_backups-bucket policy |
| production\_transition\_dbadmin\_read\_database\_backups\_bucket\_policy\_arn | ARN of the production read TransitionDBAdmin database_backups-bucket policy |
| publishing-api\_dbadmin\_write\_database\_backups\_bucket\_policy\_arn | ARN of the publishing-apiDBAdmin write database_backups-bucket policy |
| s3\_database\_backups\_bucket\_name | The name of the database backups bucket |
| staging\_dbadmin\_read\_database\_backups\_bucket\_policy\_arn | ARN of the staging read DBAdmin database_backups-bucket policy |
| staging\_elasticsearch\_read\_database\_backups\_bucket\_policy\_arn | ARN of the staging read elasticsearch database_backups-bucket policy |
| staging\_email-alert-api\_dbadmin\_read\_database\_backups\_bucket\_policy\_arn | ARN of the staging read EmailAlertAPUDBAdmin database_backups-bucket policy |
| staging\_graphite\_read\_database\_backups\_bucket\_policy\_arn | ARN of the staging read Graphite database_backups-bucket policy |
| staging\_mongo\_api\_read\_database\_backups\_bucket\_policy\_arn | ARN of the staging read mongo-api database_backups-bucket policy |
| staging\_mongo\_router\_read\_database\_backups\_bucket\_policy\_arn | ARN of the staging read router_backend database_backups-bucket policy |
| staging\_mongodb\_read\_database\_backups\_bucket\_policy\_arn | ARN of the staging read mongodb database_backups-bucket policy |
| staging\_publishing-api\_dbadmin\_read\_database\_backups\_bucket\_policy\_arn | ARN of the staging read publishing-apiDBAdmin database_backups-bucket policy |
| staging\_transition\_dbadmin\_read\_database\_backups\_bucket\_policy\_arn | ARN of the staging read TransitionDBAdmin database_backups-bucket policy |
| transition\_dbadmin\_write\_database\_backups\_bucket\_policy\_arn | ARN of the TransitionDBAdmin write database_backups-bucket policy |

