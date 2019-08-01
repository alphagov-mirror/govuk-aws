## Project: app-email-alert-api-postgresql

RDS email-alert-api PostgreSQL Primary instance

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| aws\_environment | AWS Environment | string | n/a | yes |
| aws\_region | AWS region | string | `"eu-west-1"` | no |
| cloudwatch\_log\_retention | Number of days to retain Cloudwatch logs for | string | n/a | yes |
| multi\_az | Enable multi-az. | string | `"true"` | no |
| password | DB password | string | n/a | yes |
| remote\_state\_bucket | S3 bucket we store our terraform state in | string | n/a | yes |
| remote\_state\_infra\_monitoring\_key\_stack | Override stackname path to infra_monitoring remote state | string | `""` | no |
| remote\_state\_infra\_networking\_key\_stack | Override infra_networking remote state path | string | `""` | no |
| remote\_state\_infra\_root\_dns\_zones\_key\_stack | Override stackname path to infra_root_dns_zones remote state | string | `""` | no |
| remote\_state\_infra\_security\_groups\_key\_stack | Override infra_security_groups stackname path to infra_vpc remote state | string | `""` | no |
| remote\_state\_infra\_stack\_dns\_zones\_key\_stack | Override stackname path to infra_stack_dns_zones remote state | string | `""` | no |
| remote\_state\_infra\_vpc\_key\_stack | Override infra_vpc remote state path | string | `""` | no |
| skip\_final\_snapshot | Set to true to NOT create a final snapshot when the cluster is deleted. | string | n/a | yes |
| snapshot\_identifier | Specifies whether or not to create the database from this snapshot | string | `""` | no |
| stackname | Stackname | string | n/a | yes |
| username | PostgreSQL username | string | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| email-alert-api-postgresql-primary\_address | email-alert-api-postgresql instance address |
| email-alert-api-postgresql-primary\_endpoint | email-alert-api-postgresql instance endpoint |
| email-alert-api-postgresql-primary\_id | email-alert-api-postgresql instance ID |
| email-alert-api-postgresql-primary\_resource\_id | email-alert-api-postgresql instance resource ID |
| email-alert-api-postgresql-standby-address | email-alert-api-postgresql replica instance address |
| email-alert-api-postgresql-standby-endpoint | email-alert-api-postgresql replica instance endpoint |

