## Project: infra-root-dns-zones

This module creates the internal and external root DNS zones.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| aws\_region | AWS region | string | `"eu-west-1"` | no |
| create\_external\_zone | Create an external DNS zone (default true) | string | `"true"` | no |
| create\_internal\_zone | Create an internal DNS zone (default true) | string | `"true"` | no |
| create\_internal\_zone\_dns\_validation | Create a public DNS zone to validate the internal domain certificate (default false) | string | `"false"` | no |
| remote\_state\_bucket | S3 bucket we store our terraform state in | string | n/a | yes |
| remote\_state\_infra\_vpc\_key\_stack | Override infra_vpc remote state path | string | `""` | no |
| root\_domain\_external\_name | External DNS root domain name. Override default for Integration, Staging, Production if create_external_zone is true | string | `"mydomain.external"` | no |
| root\_domain\_internal\_name | Internal DNS root domain name. Override default for Integration, Staging, Production if create_internal_zone is true | string | `"mydomain.internal"` | no |
| stackname | Stackname | string | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| external\_root\_domain\_name | Route53 External Root Domain Name |
| external\_root\_zone\_id | Route53 External Root Zone ID |
| internal\_root\_dns\_validation\_zone\_id | Route53 Zone ID for DNS certificate validation of the internal domain |
| internal\_root\_domain\_name | Route53 Internal Root Domain Name |
| internal\_root\_zone\_id | Route53 Internal Root Zone ID |

