## Project: app-gatling

Gatling node

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| asg\_desired\_capacity | The autoscaling groups desired capacity | string | `"1"` | no |
| asg\_max\_size | The autoscaling groups max_size | string | `"1"` | no |
| asg\_min\_size | The autoscaling groups max_size | string | `"1"` | no |
| aws\_environment | AWS Environment | string | n/a | yes |
| aws\_region | AWS region | string | `"eu-west-1"` | no |
| ebs\_encrypted | Whether or not the EBS volume is encrypted | string | n/a | yes |
| elb\_external\_certname | The ACM cert domain name to find the ARN of | string | n/a | yes |
| external\_domain\_name | The domain name of the external DNS records, it could be different from the zone name | string | n/a | yes |
| external\_zone\_name | The name of the Route53 zone that contains external records | string | n/a | yes |
| instance\_ami\_filter\_name | Name to use to find AMI images | string | `""` | no |
| instance\_type | Instance type used for EC2 resources | string | `"m5.large"` | no |
| remote\_state\_bucket | S3 bucket we store our terraform state in | string | n/a | yes |
| remote\_state\_infra\_monitoring\_key\_stack | Override stackname path to infra_monitoring remote state | string | `""` | no |
| remote\_state\_infra\_networking\_key\_stack | Override infra_networking remote state path | string | `""` | no |
| remote\_state\_infra\_root\_dns\_zones\_key\_stack | Override stackname path to infra_root_dns_zones remote state | string | `""` | no |
| remote\_state\_infra\_security\_groups\_key\_stack | Override infra_security_groups stackname path to infra_vpc remote state | string | `""` | no |
| remote\_state\_infra\_stack\_dns\_zones\_key\_stack | Override stackname path to infra_stack_dns_zones remote state | string | `""` | no |
| remote\_state\_infra\_vpc\_key\_stack | Override infra_vpc remote state path | string | `""` | no |
| stackname | Stackname | string | n/a | yes |
| user\_data\_snippets | List of user-data snippets | list | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| instance\_iam\_role\_name | name of the instance iam role |

