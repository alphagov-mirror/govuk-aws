## Project: app-draft-cache

Draft Cache servers

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| app\_service\_records | List of application service names that get traffic via this loadbalancer | list | `<list>` | no |
| asg\_size | The autoscaling groups desired/max/min capacity | string | `"2"` | no |
| aws\_environment | AWS Environment | string | n/a | yes |
| aws\_region | AWS region | string | `"eu-west-1"` | no |
| create\_external\_elb | Create the external ELB | string | `"true"` | no |
| elb\_external\_certname | The ACM cert domain name to find the ARN of | string | n/a | yes |
| elb\_internal\_certname | The ACM cert domain name to find the ARN of | string | n/a | yes |
| external\_domain\_name | The domain name of the external DNS records, it could be different from the zone name | string | n/a | yes |
| external\_zone\_name | The name of the Route53 zone that contains external records | string | n/a | yes |
| instance\_ami\_filter\_name | Name to use to find AMI images | string | `""` | no |
| instance\_type | Instance type used for EC2 resources | string | `"t2.medium"` | no |
| internal\_domain\_name | The domain name of the internal DNS records, it could be different from the zone name | string | n/a | yes |
| internal\_zone\_name | The name of the Route53 zone that contains internal records | string | n/a | yes |
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
| draft-cache\_elb\_dns\_name | DNS name to access the draft-cache service |
| draft-cache\_external\_elb\_dns\_name | DNS name to access the draft-cache external service |
| draft-router-api\_internal\_dns\_name | DNS name to access draft-router-api |
| external\_service\_dns\_name | DNS name to access the external service |
| service\_dns\_name | DNS name to access the service |

