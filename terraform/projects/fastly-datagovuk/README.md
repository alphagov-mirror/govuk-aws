## Project: fastly-datagovuk

Manages the Fastly service for data.gov.uk

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| aws\_environment | AWS Environment | string | n/a | yes |
| aws\_region | AWS region | string | `"eu-west-1"` | no |
| backend\_domain | The domain of the data.gov.uk PaaS instance to forward requests to | string | n/a | yes |
| domain | The domain of the data.gov.uk service to manage | string | n/a | yes |
| fastly\_api\_key | API key to authenticate with Fastly | string | n/a | yes |
| logging\_aws\_access\_key\_id | IAM key ID with access to put logs into the S3 bucket | string | n/a | yes |
| logging\_aws\_secret\_access\_key | IAM secret key with access to put logs into the S3 bucket | string | n/a | yes |
| remote\_state\_bucket | S3 bucket we store our terraform state in | string | n/a | yes |
| remote\_state\_infra\_monitoring\_key\_stack | Override stackname path to infra_monitoring remote state | string | `""` | no |
| remote\_state\_infra\_networking\_key\_stack | Override infra_networking remote state path | string | `""` | no |
| remote\_state\_infra\_root\_dns\_zones\_key\_stack | Override stackname path to infra_root_dns_zones remote state | string | `""` | no |
| remote\_state\_infra\_security\_groups\_key\_stack | Override infra_security_groups stackname path to infra_vpc remote state | string | `""` | no |
| remote\_state\_infra\_stack\_dns\_zones\_key\_stack | Override stackname path to infra_stack_dns_zones remote state | string | `""` | no |
| remote\_state\_infra\_vpc\_key\_stack | Override infra_vpc remote state path | string | `""` | no |
| stackname | Stackname | string | n/a | yes |

