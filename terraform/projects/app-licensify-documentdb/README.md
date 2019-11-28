## Project: app-licensify-documentdb

DocumentDB cluster for Licensify


## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| aws_environment | AWS environment | string | - | yes |
| aws_region | AWS region | string | `eu-west-1` | no |
| backup_retention_period | Retention period in days for DocumentDB automatic snapshots | string | `1` | no |
| instance_count | Instance count used for Licensify DocumentDB resources | string | `3` | no |
| instance_type | Instance type used for Licensify DocumentDB resources | string | `db.r5.large` | no |
| master_password | Password of master user on Licensify DocumentDB cluster | string | - | yes |
| master_username | Username of master user on Licensify DocumentDB cluster | string | - | yes |
| profiler | Whether to log slow queries to CloudWatch. Must be either 'enabled' or 'disabled'. | string | `enabled` | no |
| profiler_threshold_ms | Queries which take longer than this number of milliseconds are logged to CloudWatch if profiler is enabled. Minimum is 50. | string | `300` | no |
| remote_state_bucket | S3 bucket we store our terraform state in | string | - | yes |
| remote_state_infra_networking_key_stack | Override infra_networking remote state path | string | `` | no |
| remote_state_infra_security_groups_key_stack | Override infra_security_groups stackname path to infra_vpc remote state | string | `` | no |
| remote_state_infra_security_key_stack | Override infra_security stackname path to infra_vpc remote state | string | `` | no |
| stackname | Stackname | string | - | yes |
| tls | Whether to enable or disable TLS for the Licensify DocumentDB cluster. Must be either 'enabled' or 'disabled'. | string | `enabled` | no |

## Outputs

| Name | Description |
|------|-------------|
| licensify_documentdb_endpoint | Outputs -------------------------------------------------------------- |

