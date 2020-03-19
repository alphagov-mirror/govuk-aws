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

#
# Public (external) load balancer for "backend" publisher apps.
#

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

#
# Internal load balancer for "backend" publisher apps.
#

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
# Target groups and autoscaling group attachments. Used by both ALBs.
#
# Each service on the `backend` machines has one aws_lb_target_group and one
# aws_autoscaling_attachment. Each aws_lb_target_group is referred to by up to
# two aws_lb_listener_rules, depending on whether it's behind the public LB or
# the internal LB or both.
#
# AWS has a hard limit of 50 TGs on an ASG and we have over 30 services running
# on `backend`, so we need to stick to just one TG for each service. This also
# minimises the overhead caused by healthchecks, as well as reducing
# unnecessary duplication and complexity.
#
# Generating all this using count() and lists may seem tempting, but we tried
# that and it led to extreme difficulties in making simple changes such as
# retiring a service, changing a timeout on a particular service, or avoiding
# creating unnecessary duplicate target groups for each load balancer so that
# we stay below 50 TG per ASG limit. Repetition is not the enemy here. The
# purpose of this code is to represent the config, not to be a program which
# generates config.
#

resource "aws_lb_target_group" "asset-manager" {
  name     = "backend-asset-manager"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_asset-manager"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "asset-manager" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.asset-manager.arn}"
}

resource "aws_lb_target_group" "backdrop-admin" {
  name     = "backend-backdrop-admin"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_backdrop-admin"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "backdrop-admin" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.backdrop-admin.arn}"
}

resource "aws_lb_target_group" "canary-backend" {
  name     = "backend-canary-backend"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_canary-backend"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "canary-backend" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.canary-backend.arn}"
}

resource "aws_lb_target_group" "collections-publisher" {
  name     = "backend-collections-publisher"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_collections-publisher"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "collections-publisher" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.collections-publisher.arn}"
}

resource "aws_lb_target_group" "contacts-admin" {
  name     = "backend-contacts-admin"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_contacts-admin"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "contacts-admin" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.contacts-admin.arn}"
}

resource "aws_lb_target_group" "content-data-admin" {
  name     = "backend-content-data-admin"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_content-data-admin"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "content-data-admin" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.content-data-admin.arn}"
}

resource "aws_lb_target_group" "content-data-api" {
  name     = "backend-content-data-api"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_content-data-api"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "content-data-api" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.content-data-api.arn}"
}

resource "aws_lb_target_group" "content-performance-manager" {
  name     = "backend-content-performance-mgr"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_content-performance-manager"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "content-performance-manager" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.content-performance-manager.arn}"
}

resource "aws_lb_target_group" "content-publisher" {
  name     = "backend-content-publisher"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_content-publisher"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "content-publisher" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.content-publisher.arn}"
}

resource "aws_lb_target_group" "content-tagger" {
  name     = "backend-content-tagger"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_content-tagger"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "content-tagger" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.content-tagger.arn}"
}

resource "aws_lb_target_group" "docs" {
  name     = "backend-docs"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_docs"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "docs" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.docs.arn}"
}

resource "aws_lb_target_group" "event-store" {
  name     = "backend-event-store"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_event-store"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "event-store" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.event-store.arn}"
}

resource "aws_lb_target_group" "hmrc-manuals-api" {
  name     = "backend-hmrc-manuals-api"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_hmrc-manuals-api"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "hmrc-manuals-api" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.hmrc-manuals-api.arn}"
}

resource "aws_lb_target_group" "imminence" {
  name     = "backend-imminence"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_imminence"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "imminence" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.imminence.arn}"
}

resource "aws_lb_target_group" "link-checker-api" {
  name     = "backend-link-checker-api"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_link-checker-api"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "link-checker-api" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.link-checker-api.arn}"
}

resource "aws_lb_target_group" "local-links-manager" {
  name     = "backend-local-links-manager"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_local-links-manager"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "local-links-manager" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.local-links-manager.arn}"
}

resource "aws_lb_target_group" "manuals-publisher" {
  name     = "backend-manuals-publisher"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_manuals-publisher"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "manuals-publisher" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.manuals-publisher.arn}"
}

resource "aws_lb_target_group" "maslow" {
  name     = "backend-maslow"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_maslow"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "maslow" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.maslow.arn}"
}

resource "aws_lb_target_group" "performanceplatform-admin" {
  name     = "backend-performanceplatform-adm"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_performanceplatform-admin"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "performanceplatform-admin" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.performanceplatform-admin.arn}"
}

resource "aws_lb_target_group" "policy-publisher" {
  name     = "backend-policy-publisher"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_policy-publisher"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "policy-publisher" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.policy-publisher.arn}"
}

resource "aws_lb_target_group" "publisher" {
  name     = "backend-publisher"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_publisher"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "publisher" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.publisher.arn}"
}

resource "aws_lb_target_group" "release" {
  name     = "backend-release"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_release"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "release" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.release.arn}"
}

resource "aws_lb_target_group" "search-admin" {
  name     = "backend-search-admin"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_search-admin"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "search-admin" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.search-admin.arn}"
}

resource "aws_lb_target_group" "service-manual-publisher" {
  name     = "backend-service-manual-publisher"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_service-manual-publisher"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "service-manual-publisher" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.service-manual-publisher.arn}"
}

resource "aws_lb_target_group" "short-url-manager" {
  name     = "backend-short-url-manager"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_short-url-manager"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "short-url-manager" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.short-url-manager.arn}"
}

resource "aws_lb_target_group" "signon" {
  name     = "backend-signon"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_signon"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "signon" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.signon.arn}"
}

resource "aws_lb_target_group" "specialist-publisher" {
  name     = "backend-specialist-publisher"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_specialist-publisher"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "specialist-publisher" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.specialist-publisher.arn}"
}

resource "aws_lb_target_group" "support-api" {
  name     = "backend-support-api"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_support-api"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "support-api" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.support-api.arn}"
}

resource "aws_lb_target_group" "support" {
  name     = "backend-support"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_support"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "support" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.support.arn}"
}

resource "aws_lb_target_group" "transition" {
  name     = "backend-transition"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_transition"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "transition" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.transition.arn}"
}

resource "aws_lb_target_group" "travel-advice-publisher" {
  name     = "backend-travel-advice-publisher"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  tags     = "${local.common_tags}"

  health_check {
    path                = "/_healthcheck_travel-advice-publisher"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "travel-advice-publisher" {
  autoscaling_group_name = "${module.backend.autoscaling_group_name}"
  alb_target_group_arn   = "${aws_lb_target_group.travel-advice-publisher.arn}"
}

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

resource "aws_route53_record" "asset-manager-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "asset-manager"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "backdrop-admin-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.backdrop-admin.arn}"
  }

  condition {
    host_header {
      values = ["backdrop-admin.*"]
    }
  }
}

resource "aws_route53_record" "backdrop-admin-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "backdrop-admin"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "canary-backend-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 300

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.canary-backend.arn}"
  }

  condition {
    host_header {
      values = ["canary-backend.*"]
    }
  }
}

resource "aws_route53_record" "canary-backend-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "canary-backend"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "collections-publisher-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 400

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

resource "aws_route53_record" "collections-publisher-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "collections-publisher"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "contacts-admin-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 500

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.contacts-admin.arn}"
  }

  condition {
    host_header {
      values = ["contacts-admin.*"]
    }
  }
}

resource "aws_route53_record" "contacts-admin-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "contacts-admin"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "content-data-admin-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 600

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.content-data-admin.arn}"
  }

  condition {
    host_header {
      values = ["content-data-admin.*"]
    }
  }
}

resource "aws_route53_record" "content-data-admin-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "content-data-admin"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "content-data-api-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 700

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.content-data-api.arn}"
  }

  condition {
    host_header {
      values = ["content-data-api.*"]
    }
  }
}

resource "aws_route53_record" "content-data-api-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "content-data-api"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "content-performance-manager-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 800

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.content-performance-manager.arn}"
  }

  condition {
    host_header {
      values = ["content-performance-manager.*"]
    }
  }
}

resource "aws_route53_record" "content-performance-manager-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "content-performance-manager"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "content-publisher-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 900

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.content-publisher.arn}"
  }

  condition {
    host_header {
      values = ["content-publisher.*"]
    }
  }
}

resource "aws_route53_record" "content-publisher-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "content-publisher"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "content-tagger-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 1000

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.content-tagger.arn}"
  }

  condition {
    host_header {
      values = ["content-tagger.*"]
    }
  }
}

resource "aws_route53_record" "content-tagger-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "content-tagger"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "docs-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 1100

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.docs.arn}"
  }

  condition {
    host_header {
      values = ["docs.*"]
    }
  }
}

resource "aws_route53_record" "docs-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "docs"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "event-store-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 1200

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.event-store.arn}"
  }

  condition {
    host_header {
      values = ["event-store.*"]
    }
  }
}

resource "aws_route53_record" "event-store-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "event-store"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "hmrc-manuals-api-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 1300

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.hmrc-manuals-api.arn}"
  }

  condition {
    host_header {
      values = ["hmrc-manuals-api.*"]
    }
  }
}

resource "aws_route53_record" "hmrc-manuals-api-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "hmrc-manuals-api"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "imminence-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 1400

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.imminence.arn}"
  }

  condition {
    host_header {
      values = ["imminence.*"]
    }
  }
}

resource "aws_route53_record" "imminence-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "imminence"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "link-checker-api-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 1500

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.link-checker-api.arn}"
  }

  condition {
    host_header {
      values = ["link-checker-api.*"]
    }
  }
}

resource "aws_route53_record" "link-checker-api-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "link-checker-api"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "local-links-manager-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 1600

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.local-links-manager.arn}"
  }

  condition {
    host_header {
      values = ["local-links-manager.*"]
    }
  }
}

resource "aws_route53_record" "local-links-manager-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "local-links-manager"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "manuals-publisher-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 1700

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.manuals-publisher.arn}"
  }

  condition {
    host_header {
      values = ["manuals-publisher.*"]
    }
  }
}

resource "aws_route53_record" "manuals-publisher-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "manuals-publisher"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "maslow-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 1800

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.maslow.arn}"
  }

  condition {
    host_header {
      values = ["maslow.*"]
    }
  }
}

resource "aws_route53_record" "maslow-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "maslow"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "performanceplatform-admin-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 1900

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.performanceplatform-admin.arn}"
  }

  condition {
    host_header {
      values = ["performanceplatform-admin.*"]
    }
  }
}

resource "aws_route53_record" "performanceplatform-admin-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "performanceplatform-admin"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "policy-publisher-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 2000

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.policy-publisher.arn}"
  }

  condition {
    host_header {
      values = ["policy-publisher.*"]
    }
  }
}

resource "aws_route53_record" "policy-publisher-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "policy-publisher"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "publisher-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 2100

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.publisher.arn}"
  }

  condition {
    host_header {
      values = ["publisher.*"]
    }
  }
}

resource "aws_route53_record" "publisher-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "publisher"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "release-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 2200

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.release.arn}"
  }

  condition {
    host_header {
      values = ["release.*"]
    }
  }
}

resource "aws_route53_record" "release-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "release"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "search-admin-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 2300

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.search-admin.arn}"
  }

  condition {
    host_header {
      values = ["search-admin.*"]
    }
  }
}

resource "aws_route53_record" "search-admin-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "search-admin"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "service-manual-publisher-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 2400

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.service-manual-publisher.arn}"
  }

  condition {
    host_header {
      values = ["service-manual-publisher.*"]
    }
  }
}

resource "aws_route53_record" "service-manual-publisher-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "service-manual-publisher"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "short-url-manager-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 2500

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.short-url-manager.arn}"
  }

  condition {
    host_header {
      values = ["short-url-manager.*"]
    }
  }
}

resource "aws_route53_record" "short-url-manager-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "short-url-manager"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "signon-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 2600

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.signon.arn}"
  }

  condition {
    host_header {
      values = ["signon.*"]
    }
  }
}

resource "aws_route53_record" "signon-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "signon"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "specialist-publisher-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 2700

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.specialist-publisher.arn}"
  }

  condition {
    host_header {
      values = ["specialist-publisher.*"]
    }
  }
}

resource "aws_route53_record" "specialist-publisher-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "specialist-publisher"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "support-api-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 2800

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.support-api.arn}"
  }

  condition {
    host_header {
      values = ["support-api.*"]
    }
  }
}

resource "aws_route53_record" "support-api-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "support-api"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "support-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 2900

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.support.arn}"
  }

  condition {
    host_header {
      values = ["support.*"]
    }
  }
}

resource "aws_route53_record" "support-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "support"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "transition-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 3000

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.transition.arn}"
  }

  condition {
    host_header {
      values = ["transition.*"]
    }
  }
}

resource "aws_route53_record" "transition-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "transition"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "travel-advice-publisher-internal" {
  listener_arn = "${module.internal_lb.load_balancer_ssl_listeners[0]}"
  priority     = 3100

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.travel-advice-publisher.arn}"
  }

  condition {
    host_header {
      values = ["travel-advice-publisher.*"]
    }
  }
}

resource "aws_route53_record" "travel-advice-publisher-internal" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.internal_root_zone_id}"
  name    = "travel-advice-publisher"
  type    = "CNAME"
  records = ["${aws_route53_record.internal_lb_alias.fqdn}"]
  ttl     = "300"
}

#
# LB listener rules and CNAME records for services on public (external) LB.
#

resource "aws_lb_listener_rule" "asset-manager-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
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

resource "aws_route53_record" "asset-manager-external" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "asset-manager"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "collections-publisher-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
  priority     = 200

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

resource "aws_route53_record" "collections-publisher-external" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "collections-publisher"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "contacts-admin-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
  priority     = 300

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.contacts-admin.arn}"
  }

  condition {
    host_header {
      values = ["contacts-admin.*"]
    }
  }
}

resource "aws_route53_record" "contacts-admin-external" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "contacts-admin"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "content-data-admin-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
  priority     = 400

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.content-data-admin.arn}"
  }

  condition {
    host_header {
      # content-data-admin is accessed via both
      # content-data-admin.publishing.service.gov.uk and
      # content-data.publishing.service.gov.uk. The latter is canonical.
      values = ["content-data-admin.*", "content-data.*"]
    }
  }
}

resource "aws_route53_record" "content-data-admin-external" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "content-data-admin"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "content-data-api-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
  priority     = 500

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.content-data-api.arn}"
  }

  condition {
    host_header {
      values = ["content-data-api.*"]
    }
  }
}

resource "aws_route53_record" "content-data-api-external" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "content-data-api"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "content-performance-manager-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
  priority     = 600

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.content-performance-manager.arn}"
  }

  condition {
    host_header {
      values = ["content-performance-manager.*"]
    }
  }
}

resource "aws_route53_record" "content-performance-manager-external" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "content-performance-manager"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "content-publisher-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
  priority     = 700

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.content-publisher.arn}"
  }

  condition {
    host_header {
      values = ["content-publisher.*"]
    }
  }
}

resource "aws_route53_record" "content-publisher-external" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "content-publisher"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "content-tagger-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
  priority     = 800

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.content-tagger.arn}"
  }

  condition {
    host_header {
      values = ["content-tagger.*"]
    }
  }
}

resource "aws_route53_record" "content-tagger-external" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "content-tagger"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "docs-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
  priority     = 900

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.docs.arn}"
  }

  condition {
    host_header {
      values = ["docs.*"]
    }
  }
}

resource "aws_route53_record" "docs-external" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "docs"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "hmrc-manuals-api-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
  priority     = 1000

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.hmrc-manuals-api.arn}"
  }

  condition {
    host_header {
      values = ["hmrc-manuals-api.*"]
    }
  }
}

resource "aws_route53_record" "hmrc-manuals-api-external" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "hmrc-manuals-api"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "imminence-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
  priority     = 1100

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.imminence.arn}"
  }

  condition {
    host_header {
      values = ["imminence.*"]
    }
  }
}

resource "aws_route53_record" "imminence-external" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "imminence"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "local-links-manager-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
  priority     = 1200

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.local-links-manager.arn}"
  }

  condition {
    host_header {
      values = ["local-links-manager.*"]
    }
  }
}

resource "aws_route53_record" "local-links-manager-external" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "local-links-manager"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "manuals-publisher-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
  priority     = 1300

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.manuals-publisher.arn}"
  }

  condition {
    host_header {
      values = ["manuals-publisher.*"]
    }
  }
}

resource "aws_route53_record" "manuals-publisher-external" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "manuals-publisher"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "maslow-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
  priority     = 1400

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.maslow.arn}"
  }

  condition {
    host_header {
      values = ["maslow.*"]
    }
  }
}

resource "aws_route53_record" "maslow-external" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "maslow"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "policy-publisher-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
  priority     = 1500

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.policy-publisher.arn}"
  }

  condition {
    host_header {
      values = ["policy-publisher.*"]
    }
  }
}

resource "aws_route53_record" "policy-publisher-external" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "policy-publisher"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "publisher-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
  priority     = 1600

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.publisher.arn}"
  }

  condition {
    host_header {
      values = ["publisher.*"]
    }
  }
}

resource "aws_route53_record" "publisher-external" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "publisher"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "release-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
  priority     = 1700

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.release.arn}"
  }

  condition {
    host_header {
      values = ["release.*"]
    }
  }
}

resource "aws_route53_record" "release-external" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "release"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "search-admin-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
  priority     = 1800

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.search-admin.arn}"
  }

  condition {
    host_header {
      values = ["search-admin.*"]
    }
  }
}

resource "aws_route53_record" "search-admin-external" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "search-admin"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "service-manual-publisher-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
  priority     = 1900

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.service-manual-publisher.arn}"
  }

  condition {
    host_header {
      values = ["service-manual-publisher.*"]
    }
  }
}

resource "aws_route53_record" "service-manual-publisher-external" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "service-manual-publisher"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "short-url-manager-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
  priority     = 2000

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.short-url-manager.arn}"
  }

  condition {
    host_header {
      values = ["short-url-manager.*"]
    }
  }
}

resource "aws_route53_record" "short-url-manager-external" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "short-url-manager"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "signon-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
  priority     = 2100

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.signon.arn}"
  }

  condition {
    host_header {
      values = ["signon.*"]
    }
  }
}

resource "aws_route53_record" "signon-external" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "signon"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "specialist-publisher-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
  priority     = 2200

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.specialist-publisher.arn}"
  }

  condition {
    host_header {
      values = ["specialist-publisher.*"]
    }
  }
}

resource "aws_route53_record" "specialist-publisher-external" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "specialist-publisher"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "support-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
  priority     = 2300

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.support.arn}"
  }

  condition {
    host_header {
      values = ["support.*"]
    }
  }
}

resource "aws_route53_record" "support-external" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "support"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "transition-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
  priority     = 2400

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.transition.arn}"
  }

  condition {
    host_header {
      values = ["transition.*"]
    }
  }
}

resource "aws_route53_record" "transition-external" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "transition"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

resource "aws_lb_listener_rule" "travel-advice-publisher-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"
  priority     = 2500

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.travel-advice-publisher.arn}"
  }

  condition {
    host_header {
      values = ["travel-advice-publisher.*"]
    }
  }
}

resource "aws_route53_record" "travel-advice-publisher-external" {
  zone_id = "${data.terraform_remote_state.infra_root_dns_zones.external_root_zone_id}"
  name    = "travel-advice-publisher"
  type    = "CNAME"
  records = ["${aws_route53_record.public_lb_alias.fqdn}"]
  ttl     = "300"
}

# Return 400 when host is unknown. This is to ensure that there is no L7
# ingress to internal-only "backend" apps from the Internet. Ideally we would
# make this the default listener action rather than another rule, but our
# "aws/lb" module makes that impossible without a major refactoring.
#
# 400 Bad Request is the standard response for a bad Host header field-value.
# https://tools.ietf.org/html/rfc7230#section-5.4
#
# TODO: refactor our "aws/lb" module so that we can use the default listener
# action, which would be a cleaner and less surprising way to achieve this.

resource "aws_lb_listener_rule" "reject-requests-to-unknown-hosts-external" {
  listener_arn = "${module.public_lb.load_balancer_ssl_listeners[0]}"

  # This rule needs to have the lowest precedence (highest priority number).
  priority = 49000

  action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "400 Bad Request (unknown host)"
      status_code  = "400"
    }
  }

  # This is just a match-all condition. It's only here because AWS requires at
  # least one condition and doesn't allow an empty condition (because you're
  # supposed to use the default listener action, but we can't because of our
  # "aws/lb" module).
  condition {
    source_ip {
      values = ["0.0.0.0/0", "::/0"]
    }
  }
}
