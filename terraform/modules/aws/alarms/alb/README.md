## Modules: aws/alarm/alb

This module creates the following CloudWatch alarms in the
AWS/ApplicationELB namespace:

  - HTTPCode_Target_4XX_Count greater than or equal to threshold
  - HTTPCode_Target_5XX_Count greater than or equal to threshold
  - HTTPCode_ELB_4XX_Count greater than or equal to threshold
  - HTTPCode_ELB_5XX_Count greater than or equal to threshold

All metrics are measured during a period of 60 seconds and evaluated
during 5 consecutive periods.

To disable any alarm, set the threshold parameter to 0.

AWS/ApplicationELB metrics reference:

http://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/elb-metricscollected.html#load-balancer-metric-dimensions-alb

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| alarm\_actions | The list of actions to execute when this alarm transitions into an ALARM state. Each action is specified as an Amazon Resource Number (ARN). | list | `<list>` | no |
| alb\_arn\_suffix | The ALB ARN suffix for use with CloudWatch Metrics. | string | n/a | yes |
| httpcode\_elb\_4xx\_count\_threshold | The value against which the HTTPCode_ELB_4XX_Count metric is compared. | string | `"0"` | no |
| httpcode\_elb\_5xx\_count\_threshold | The value against which the HTTPCode_ELB_5XX_Count metric is compared. | string | `"80"` | no |
| httpcode\_target\_4xx\_count\_threshold | The value against which the HTTPCode_Target_4XX_Count metric is compared. | string | `"0"` | no |
| httpcode\_target\_5xx\_count\_threshold | The value against which the HTTPCode_Target_5XX_Count metric is compared. | string | `"80"` | no |
| name\_prefix | The alarm name prefix. | string | n/a | yes |

