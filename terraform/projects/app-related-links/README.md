## Project: app-related-links

Related Links

Run resource intensive scripts for data science purposes.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| aws\_environment | AWS environment | string | n/a | yes |
| aws\_region | AWS region | string | `"eu-west-1"` | no |
| concourse\_aws\_account\_id | AWS account ID which contains the Concourse role | string | n/a | yes |
| remote\_state\_bucket | S3 bucket we store our terraform state in | string | n/a | yes |
| remote\_state\_infra\_database\_backups\_bucket\_key\_stack | Override stackname path to infra_database_backups_bucket remote state | string | `""` | no |
| remote\_state\_infra\_monitoring\_key\_stack | Override stackname path to infra_monitoring remote state | string | `""` | no |
| remote\_state\_infra\_networking\_key\_stack | Override infra_networking remote state path | string | `""` | no |
| remote\_state\_infra\_root\_dns\_zones\_key\_stack | Override stackname path to infra_root_dns_zones remote state | string | `""` | no |
| remote\_state\_infra\_security\_groups\_key\_stack | Override infra_security_groups stackname path to infra_vpc remote state | string | `""` | no |
| remote\_state\_infra\_stack\_dns\_zones\_key\_stack | Override stackname path to infra_stack_dns_zones remote state | string | `""` | no |
| remote\_state\_infra\_vpc\_key\_stack | Override infra_vpc remote state path | string | `""` | no |
| stackname | Stackname | string | n/a | yes |

