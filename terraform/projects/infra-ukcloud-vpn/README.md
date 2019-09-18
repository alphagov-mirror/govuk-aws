## Module: projects/infra-ukcloud-vpn

Creates a VPN for AWS to connect to ukcloud


## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| aws_region | AWS region | string | `eu-west-1` | no |
| aws_vpn_gateway_id | ID of Virtual Private Gateway to use with VPN | string | `` | no |
| civica_cidr | Civica ip/network range | string | - | yes |
| remote_state_bucket | S3 bucket we store our terraform state in | string | - | yes |
| remote_state_infra_networking_key_stack | Override stackname path to infra_monitoring remote state | string | `` | no |
| remote_state_infra_vpc_key_stack | Override stackname path to infra_monitoring remote state | string | `` | no |
| stackname | Stackname | string | `` | no |
| ukcloud_internal_net_cidr | Internal network range of the environment in ukcloud | string | - | yes |
| ukcloud_vpn_endpoint_ip | Public IP address of the VPN gateway in ukcloud | string | - | yes |

## Outputs

| Name | Description |
|------|-------------|
| aws_vpn_connection_id | The ID of the AWS to ukcloud VPN |

