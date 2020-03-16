/**
* ## Project: app-backend
*
* Backend node
*/
variable "aws_region" {
  type        = "string"
  description = "AWS region"
  default     = "eu-west-1"
}

variable "stackname" {
  type        = "string"
  description = "Stackname"
}

variable "aws_environment" {
  type        = "string"
  description = "AWS Environment"
}

variable "instance_ami_filter_name" {
  type        = "string"
  description = "Name to use to find AMI images"
  default     = ""
}

variable "elb_public_certname" {
  type        = "string"
  description = "The ACM cert domain name to find the ARN of"
}

variable "elb_internal_certname" {
  type        = "string"
  description = "The ACM cert domain name to find the ARN of"
}

variable "app_service_records" {
  type        = "list"
  description = "List of application service names that get traffic via this loadbalancer"
  default     = []
}

variable "asg_size" {
  type        = "string"
  description = "The autoscaling groups desired/max/min capacity"
  default     = "2"
}

# TODO: remove once Prod traffic is moved off the classic ELB.
variable "internal_zone_name" {
  type        = "string"
  description = "The name of the Route53 zone that contains internal records"
}

# TODO: remove once Prod traffic is moved off the classic ELB.
variable "internal_domain_name" {
  type        = "string"
  description = "The domain name of the internal DNS records, it could be different from the zone name"
}

variable "instance_type" {
  type        = "string"
  description = "Instance type used for EC2 resources"
  default     = "m5.2xlarge"
}

# Resources
# --------------------------------------------------------------
terraform {
  backend          "s3"             {}
  required_version = "= 0.11.14"
}

provider "aws" {
  region  = "${var.aws_region}"
  version = "2.46.0"
}

locals {
  common_tags = {
    Project         = "${var.stackname}"
    aws_migration   = "backend"
    aws_environment = "${var.aws_environment}"
  }
}

# TODO: remove once Prod traffic is moved off the classic ELB.
data "aws_route53_zone" "internal" {
  name         = "${var.internal_zone_name}"
  private_zone = true
}

# TODO: remove once Prod traffic is moved off the classic ELB.
data "aws_acm_certificate" "elb_internal_cert" {
  domain   = "${var.elb_internal_certname}"
  statuses = ["ISSUED"]
}

# TODO: remove once Prod traffic is moved off this classic ELB.
resource "aws_elb" "backend_elb_internal" {
  name            = "${var.stackname}-backend-internal"
  subnets         = ["${data.terraform_remote_state.infra_networking.private_subnet_ids}"]
  security_groups = ["${data.terraform_remote_state.infra_security_groups.sg_backend_elb_internal_id}"]
  internal        = "true"

  access_logs {
    bucket        = "${data.terraform_remote_state.infra_monitoring.aws_logging_bucket_id}"
    bucket_prefix = "elb/${var.stackname}-backend-internal-elb"
    interval      = 60
  }

  listener {
    instance_port     = "80"
    instance_protocol = "http"
    lb_port           = "443"
    lb_protocol       = "https"

    ssl_certificate_id = "${data.aws_acm_certificate.elb_internal_cert.arn}"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/_healthcheck"
    interval            = 30
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = "${map("Name", "${var.stackname}-backend", "Project", var.stackname, "aws_environment", var.aws_environment, "aws_migration", "backend")}"
}

# TODO: remove once Prod traffic is moved off the classic ELB.
resource "aws_route53_record" "service_record_internal" {
  zone_id = "${data.aws_route53_zone.internal.zone_id}"
  name    = "backend.${var.internal_domain_name}"
  type    = "A"

  alias {
    name                   = "${aws_elb.backend_elb_internal.dns_name}"
    zone_id                = "${aws_elb.backend_elb_internal.zone_id}"
    evaluate_target_health = true
  }
}

# TODO: remove once Prod traffic is moved off the classic ELB.
resource "aws_route53_record" "app_service_records_internal" {
  count   = "${length(var.app_service_records)}"
  zone_id = "${data.aws_route53_zone.internal.zone_id}"
  name    = "${element(var.app_service_records, count.index)}.${var.internal_domain_name}"
  type    = "CNAME"
  records = ["backend.${var.internal_domain_name}."]
  ttl     = "300"
}

module "backend" {
  source                        = "../../modules/aws/node_group"
  name                          = "${var.stackname}-backend"
  default_tags                  = "${map("Project", var.stackname, "aws_stackname", var.stackname, "aws_environment", var.aws_environment, "aws_migration", "backend", "aws_hostname", "backend-1")}"
  instance_subnet_ids           = "${data.terraform_remote_state.infra_networking.private_subnet_ids}"
  instance_security_group_ids   = ["${data.terraform_remote_state.infra_security_groups.sg_backend_id}", "${data.terraform_remote_state.infra_security_groups.sg_management_id}", "${data.terraform_remote_state.infra_security_groups.sg_aws-vpn_id}"]
  instance_type                 = "${var.instance_type}"
  instance_additional_user_data = "${join("\n", null_resource.user_data.*.triggers.snippet)}"

  # TODO: remove instance_elb_ids* once Prod traffic is moved off the classic ELB.
  instance_elb_ids_length       = 1
  instance_elb_ids              = ["${aws_elb.backend_elb_internal.id}"]
  instance_ami_filter_name      = "${var.instance_ami_filter_name}"
  asg_max_size                  = "${var.asg_size}"
  asg_min_size                  = "${var.asg_size}"
  asg_desired_capacity          = "${var.asg_size}"
  asg_notification_topic_arn    = "${data.terraform_remote_state.infra_monitoring.sns_topic_autoscaling_group_events_arn}"
  root_block_device_volume_size = "60"
}

# TODO: remove once Prod traffic is moved off the classic ELB.
module "alarms-elb-backend-internal" {
  source                         = "../../modules/aws/alarms/elb"
  name_prefix                    = "${var.stackname}-backend-internal"
  alarm_actions                  = ["${data.terraform_remote_state.infra_monitoring.sns_topic_cloudwatch_alarms_arn}"]
  elb_name                       = "${aws_elb.backend_elb_internal.name}"
  httpcode_backend_4xx_threshold = "0"
  httpcode_backend_5xx_threshold = "100"
  httpcode_elb_4xx_threshold     = "100"
  httpcode_elb_5xx_threshold     = "100"
  surgequeuelength_threshold     = "0"
  healthyhostcount_threshold     = "0"
}

module "public_lb" {
  source                           = "../../modules/aws/lb"
  name                             = "govuk-backend-public"
  internal                         = false
  vpc_id                           = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  access_logs_bucket_name          = "${data.terraform_remote_state.infra_monitoring.aws_logging_bucket_id}"
  access_logs_bucket_prefix        = "elb/govuk-backend-public-elb"
  listener_certificate_domain_name = "${var.elb_public_certname}"

  listener_action = {
    "HTTPS:443" = "HTTP:80"
  }

  subnets         = ["${data.terraform_remote_state.infra_networking.public_subnet_ids}"]
  security_groups = ["${data.terraform_remote_state.infra_security_groups.sg_backend_elb_external_id}"]
  alarm_actions   = ["${data.terraform_remote_state.infra_monitoring.sns_topic_cloudwatch_alarms_arn}"]
  default_tags    = "${local.common_tags}"
}

# TODO: return 400 when hostname is unknown
# (https://tools.ietf.org/html/rfc7230#section-5.4). This is important to
# ensure that there is no L7 ingress to internal-only "backend" apps from the
# Internet.

resource "aws_wafregional_web_acl_association" "public_lb" {
  resource_arn = "${module.public_lb.lb_id}"
  web_acl_id   = "${data.terraform_remote_state.infra_public_services.default_waf_acl}"
}

resource "aws_route53_record" "public_lb_alias" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "backend"
  type    = "A"

  alias {
    name                   = "${module.public_lb.lb_dns_name}"
    zone_id                = "${module.public_lb.lb_zone_id}"
    evaluate_target_health = true
  }
}

module "internal_lb" {
  source                           = "../../modules/aws/lb"
  name                             = "govuk-backend-internal"
  internal                         = true
  vpc_id                           = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  access_logs_bucket_name          = "${data.terraform_remote_state.infra_monitoring.aws_logging_bucket_id}"
  access_logs_bucket_prefix        = "elb/govuk-backend-internal-elb"
  listener_certificate_domain_name = "${var.elb_internal_certname}"

  listener_action = {
    "HTTPS:443" = "HTTP:80"
  }

  subnets         = ["${data.terraform_remote_state.infra_networking.private_subnet_ids}"]
  security_groups = ["${data.terraform_remote_state.infra_security_groups.sg_backend_elb_internal_id}"]
  alarm_actions   = ["${data.terraform_remote_state.infra_monitoring.sns_topic_cloudwatch_alarms_arn}"]

  default_tags = "${local.common_tags}"
}

resource "aws_route53_record" "internal_lb_alias" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "backend"
  type    = "A"

  alias {
    name                   = "${module.internal_lb.lb_dns_name}"
    zone_id                = "${module.internal_lb.lb_zone_id}"
    evaluate_target_health = true
  }
}

#
# Target groups and autoscaling group attachments.
#
# Each service on the `backend` machines has one aws_lb_target_group and one
# aws_autoscaling_attachment. Each aws_lb_target_group is referred to by up to
# two aws_lb_listener_rules, depending on whether it's behind the public LB or
# the internal LB or both.
#
# AWS has a hard limit of 50 TGs on an ASG and we have over 30 services running
# on `backend`, so we need to stick to just one TG for each service. This also
# minimises the overhead caused by healthchecks.
#
# Generating all this using count() and lists may seem tempting, but we tried
# that and it led to extreme difficulties in making simple changes such as
# retiring a service, changing a timeout on a particular service, or avoiding
# creating unnecessary duplicate target groups for each load balancer so that
# we stay below 50 TG per ASG limit. Repetition is not the enemy here; this is
# config, not application logic.
#

resource "aws_lb_target_group" "asset-manager" {
  name     = "backend-asset-manager"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    interval            = 30
    path                = "/_healthcheck_asset-manager"
    matcher             = "200-399"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }
}

resource "aws_autoscaling_attachment" "asset-manager" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.asset-manager.arn}"
}

resource "aws_lb_target_group" "collections-publisher" {
  name     = "backend-collections-publisher"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    interval            = 30
    path                = "/_healthcheck_collections-publisher"
    matcher             = "200-399"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }
}

resource "aws_autoscaling_attachment" "collections-publisher" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.collections-publisher.arn}"
}

# TODO: add TGs and ASG attachments for the rest of the services from backend_public_service_cnames and app_service_records (without duplicates).

#
# LB listener rules and CNAME records for services on internal LB.
#

resource "aws_lb_listener_rule" "asset-manager-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.asset-manager.arn}"
  }

  condition {
    host_header {
      values = ["asset-manager.*"]
    }
  }
}

resource "aws_route53_record" "internal_lb_cname_asset_manager" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "asset-manager"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

# TODO: add listener rules and CNAMEs for the rest of the app_service_records services.

#
# LB listener rules and CNAME records for services on public (external) LB.
#

resource "aws_lb_listener_rule" "collections-publisher-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.collections-publisher.arn}"
  }

  condition {
    host_header {
      values = ["collections-publisher.*"]
    }
  }
}

resource "aws_route53_record" "public_lb_cname_collections_publisher" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "collections-publisher"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

# TODO: add listener rules and CNAMEs for the rest of the backend_public_service_cnames services.

