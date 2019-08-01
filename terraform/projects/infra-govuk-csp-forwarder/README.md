## Module: govuk-csp-forwarder

Configures a role and Lambda function to collect Content Security Policy
reports, filter them and forward them to Sentry.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| aws\_region | AWS region | string | `"eu-west-2"` | no |
| remote\_state\_bucket | S3 bucket we store our terraform state in | string | n/a | yes |
| remote\_state\_infra\_monitoring\_key\_stack | Override stackname path to infra_monitoring remote state | string | `""` | no |
| remote\_state\_infra\_networking\_key\_stack | Override infra_networking remote state path | string | `""` | no |
| remote\_state\_infra\_root\_dns\_zones\_key\_stack | Override stackname path to infra_root_dns_zones remote state | string | `""` | no |
| remote\_state\_infra\_security\_groups\_key\_stack | Override infra_security_groups stackname path to infra_vpc remote state | string | `""` | no |
| remote\_state\_infra\_stack\_dns\_zones\_key\_stack | Override stackname path to infra_stack_dns_zones remote state | string | `""` | no |
| remote\_state\_infra\_vpc\_key\_stack | Override infra_vpc remote state path | string | `""` | no |
| stackname | Stackname | string | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| govuk\_csp\_forwarder\_report\_url |  |

