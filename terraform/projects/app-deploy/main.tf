/**
* ## Project: app-deploy
*
* Deploy node
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

variable "ebs_encrypted" {
  type        = "string"
  description = "Whether or not the EBS volume is encrypted"
}

variable "instance_ami_filter_name" {
  type        = "string"
  description = "Name to use to find AMI images"
  default     = ""
}

variable "elb_external_certname" {
  type        = "list"
  description = "The ACM cert domain name to find the ARN of"
}

variable "elb_internal_certname" {
  type        = "string"
  description = "The ACM cert domain name to find the ARN of"
}

variable "deploy_subnet" {
  type        = "string"
  description = "Name of the subnet to place the apt instance 1 and EBS volume"
}

variable "remote_state_infra_artefact_bucket_key_stack" {
  type        = "string"
  description = "Override infra_artefact_bucket remote state path"
  default     = ""
}

variable "external_zone_name" {
  type        = "string"
  description = "The name of the Route53 zone that contains external records"
}

variable "external_domain_name" {
  type        = "string"
  description = "The domain name of the external DNS records, it could be different from the zone name"
}

variable "internal_zone_name" {
  type        = "string"
  description = "The name of the Route53 zone that contains internal records"
}

variable "internal_domain_name" {
  type        = "string"
  description = "The domain name of the internal DNS records, it could be different from the zone name"
}

variable "enable_public_alb" {
  description = "Enable the use of ALBs for public access or use original ELB resources instead"
  default     = false
}

# Resources
# --------------------------------------------------------------
terraform {
  backend          "s3"             {}
  required_version = "= 0.11.7"
}

# This is one of two places that should need to use this particular remote state
# so keep it in main
data "terraform_remote_state" "artefact_bucket" {
  backend = "s3"

  config {
    bucket = "${var.remote_state_bucket}"
    key    = "${coalesce(var.remote_state_infra_artefact_bucket_key_stack, var.stackname)}/infra-artefact-bucket.tfstate"
    region = "${var.aws_region}"
  }
}

provider "aws" {
  region  = "${var.aws_region}"
  version = "1.40.0"
}

locals {
  common_tags = {
    Project         = "${var.stackname}"
    aws_environment = "${var.aws_environment}"
    aws_migration   = "jenkins"
    aws_stackname   = "${var.stackname}"
  }
}

data "aws_route53_zone" "external" {
  name         = "${var.external_zone_name}"
  private_zone = false
}

data "aws_route53_zone" "internal" {
  name         = "${var.internal_zone_name}"
  private_zone = true
}

data "aws_acm_certificate" "elb_external_cert" {
  count = "${length(var.elb_external_certname)}"

  domain   = "${var.elb_external_certname[count.index]}"
  statuses = ["ISSUED"]
}

data "aws_acm_certificate" "elb_internal_cert" {
  domain   = "${var.elb_internal_certname}"
  statuses = ["ISSUED"]
}

resource "aws_elb" "deploy_elb" {
  count = "${var.enable_public_alb ? 0 : 1}"

  name            = "${var.stackname}-deploy"
  subnets         = ["${data.terraform_remote_state.infra_networking.public_subnet_ids}"]
  security_groups = ["${data.terraform_remote_state.infra_security_groups.sg_deploy_elb_id}"]
  internal        = "false"

  access_logs {
    bucket        = "${data.terraform_remote_state.infra_monitoring.aws_logging_bucket_id}"
    bucket_prefix = "elb/${var.stackname}-deploy-external-elb"
    interval      = 60
  }

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 443
    lb_protocol       = "https"

    ssl_certificate_id = "${data.aws_acm_certificate.elb_external_cert.0.arn}"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3

    target   = "TCP:80"
    interval = 30
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = "${merge(local.common_tags, map("Name", "${var.stackname}-deploy"))}"
}

resource "aws_elb" "deploy_internal_elb" {
  name            = "${var.stackname}-deploy-internal"
  subnets         = ["${data.terraform_remote_state.infra_networking.private_subnet_ids}"]
  security_groups = ["${data.terraform_remote_state.infra_security_groups.sg_deploy_internal_elb_id}"]
  internal        = "true"

  access_logs {
    bucket        = "${data.terraform_remote_state.infra_monitoring.aws_logging_bucket_id}"
    bucket_prefix = "elb/${var.stackname}-deploy-internal-elb"
    interval      = 60
  }

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 443
    lb_protocol       = "https"

    ssl_certificate_id = "${data.aws_acm_certificate.elb_internal_cert.arn}"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3

    target   = "TCP:80"
    interval = 30
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = "${merge(local.common_tags, map("Name", "${var.stackname}-deploy-internal"))}"
}

resource "aws_lb" "deploy_public" {
  count = "${var.enable_public_alb}"

  name            = "${var.stackname}-deploy-public"
  internal        = "false"
  security_groups = ["${data.terraform_remote_state.infra_security_groups.sg_deploy_elb_id}"]
  subnets         = ["${data.terraform_remote_state.infra_networking.public_subnet_ids}"]

  access_logs {
    enabled = true
    bucket  = "${data.terraform_remote_state.infra_monitoring.aws_logging_bucket_id}"
    prefix  = "elb/${var.stackname}-deploy-public-elb"
  }

  tags = "${merge(local.common_tags, map("Name", "${var.stackname}-deploy-public"))}"
}

resource "aws_lb_listener" "deploy_public" {
  count = "${var.enable_public_alb}"

  load_balancer_arn = "${aws_lb.deploy_public.arn}"
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = "${data.aws_acm_certificate.elb_external_cert.0.arn}"

  default_action {
    target_group_arn = "${aws_lb_target_group.deploy_public.arn}"
    type             = "forward"
  }
}

resource "aws_lb_listener_certificate" "deploy_public_secondary" {
  count = "${var.enable_public_alb ? length(var.elb_external_certname) - 1 : 0}"

  listener_arn    = "${aws_lb_listener.deploy_public.arn}"
  certificate_arn = "${data.aws_acm_certificate.elb_external_cert.*.arn[count.index + 1]}"
}

resource "aws_lb_target_group" "deploy_public" {
  count = "${var.enable_public_alb}"

  port                 = "80"
  protocol             = "HTTP"
  vpc_id               = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  deregistration_delay = "300"

  health_check {
    interval            = 30
    path                = "/_healthcheck"
    matcher             = "200"
    port                = "80"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }

  tags = "${merge(local.common_tags, map("Name", "${var.stackname}-deploy-public-HTTP-80"))}"
}

resource "aws_route53_record" "service_record" {
  count = "${var.enable_public_alb ? 0 : 1}"

  zone_id = "${data.aws_route53_zone.external.zone_id}"
  name    = "deploy.${var.external_domain_name}"
  type    = "A"

  alias {
    name                   = "${aws_elb.deploy_elb.dns_name}"
    zone_id                = "${aws_elb.deploy_elb.zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "service_record_internal" {
  zone_id = "${data.aws_route53_zone.internal.zone_id}"
  name    = "deploy.${var.internal_domain_name}"
  type    = "A"

  alias {
    name                   = "${aws_elb.deploy_internal_elb.dns_name}"
    zone_id                = "${aws_elb.deploy_internal_elb.zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "service_record_public" {
  count = "${var.enable_public_alb}"

  zone_id = "${data.aws_route53_zone.external.zone_id}"
  name    = "deploy.${var.external_domain_name}"
  type    = "A"

  alias {
    name                   = "${aws_lb.deploy_public.dns_name}"
    zone_id                = "${aws_lb.deploy_public.zone_id}"
    evaluate_target_health = true
  }
}

locals {
  instance_elb_ids_length           = "${var.enable_public_alb ? 1 : 2}"
  instance_elb_ids                  = "${compact(list(join("", aws_elb.deploy_elb.*.id), aws_elb.deploy_internal_elb.id))}"
  instance_target_group_arns_length = "${var.enable_public_alb ? 1 : 0}"
  instance_target_group_arns        = "${compact(aws_lb_target_group.deploy_public.*.arn)}"
}

module "deploy" {
  source                            = "../../modules/aws/node_group"
  name                              = "${var.stackname}-deploy"
  vpc_id                            = "${data.terraform_remote_state.infra_vpc.vpc_id}"
  default_tags                      = "${merge(map("aws_hostname", "jenkins-1"), local.common_tags)}"
  instance_subnet_ids               = "${matchkeys(values(data.terraform_remote_state.infra_networking.private_subnet_names_ids_map), keys(data.terraform_remote_state.infra_networking.private_subnet_names_ids_map), list(var.deploy_subnet))}"
  instance_security_group_ids       = ["${data.terraform_remote_state.infra_security_groups.sg_deploy_id}", "${data.terraform_remote_state.infra_security_groups.sg_management_id}"]
  instance_type                     = "t2.medium"
  instance_elb_ids_length           = "${local.instance_elb_ids_length}"
  instance_elb_ids                  = ["${local.instance_elb_ids}"]
  instance_target_group_arns_length = "${local.instance_target_group_arns_length}"
  instance_target_group_arns        = ["${local.instance_target_group_arns}"]
  instance_additional_user_data     = "${join("\n", null_resource.user_data.*.triggers.snippet)}"
  instance_ami_filter_name          = "${var.instance_ami_filter_name}"
  asg_notification_topic_arn        = "${data.terraform_remote_state.infra_monitoring.sns_topic_autoscaling_group_events_arn}"
}

resource "aws_ebs_volume" "deploy" {
  availability_zone = "${lookup(data.terraform_remote_state.infra_networking.private_subnet_names_azs_map, var.deploy_subnet)}"
  encrypted         = "${var.ebs_encrypted}"
  size              = 40
  type              = "gp2"

  tags {
    Name            = "${var.stackname}-deploy"
    Project         = "${var.stackname}"
    Device          = "xvdf"
    aws_hostname    = "jenkins-1"
    aws_migration   = "jenkins"
    aws_stackname   = "${var.stackname}"
    aws_environment = "${var.aws_environment}"
  }
}

resource "aws_iam_policy" "deploy_iam_policy" {
  name   = "${var.stackname}-deploy-additional"
  path   = "/"
  policy = "${file("${path.module}/additional_policy.json")}"
}

resource "aws_iam_role_policy_attachment" "deploy_iam_role_policy_attachment" {
  role       = "${module.deploy.instance_iam_role_name}"
  policy_arn = "${aws_iam_policy.deploy_iam_policy.arn}"
}

resource "aws_iam_role_policy_attachment" "allow_writes_from_artefact_bucket" {
  role       = "${module.deploy.instance_iam_role_name}"
  policy_arn = "${data.terraform_remote_state.artefact_bucket.write_artefact_bucket_policy_arn}"
}

resource "aws_iam_role_policy_attachment" "allow_reads_from_artefact_bucket" {
  role       = "${module.deploy.instance_iam_role_name}"
  policy_arn = "${data.terraform_remote_state.artefact_bucket.read_artefact_bucket_policy_arn}"
}

locals {
  elb_httpcode_backend_5xx_threshold      = "${var.enable_public_alb ? 0 : 50}"
  elb_httpcode_elb_5xx_threshold          = "${var.enable_public_alb ? 0 : 50}"
  alb_httpcode_target_5xx_count_threshold = "${var.enable_public_alb ? 80 : 0}"
  alb_httpcode_elb_5xx_count_threshold    = "${var.enable_public_alb ? 80 : 0}"
}

module "alarms-elb-deploy-external" {
  source                         = "../../modules/aws/alarms/elb"
  name_prefix                    = "${var.stackname}-deploy-external"
  alarm_actions                  = ["${data.terraform_remote_state.infra_monitoring.sns_topic_cloudwatch_alarms_arn}"]
  elb_name                       = "${join("", aws_elb.deploy_elb.*.name)}"
  httpcode_backend_5xx_threshold = "${local.elb_httpcode_backend_5xx_threshold}"
  httpcode_elb_5xx_threshold     = "${local.elb_httpcode_elb_5xx_threshold}"
  httpcode_backend_4xx_threshold = "0"
  httpcode_elb_4xx_threshold     = "0"
  surgequeuelength_threshold     = "0"
  healthyhostcount_threshold     = "0"
}

module "alarms-alb-deploy-public" {
  source                              = "../../modules/aws/alarms/alb"
  name_prefix                         = "${var.stackname}-deploy-public"
  alarm_actions                       = ["${data.terraform_remote_state.infra_monitoring.sns_topic_cloudwatch_alarms_arn}"]
  alb_arn_suffix                      = "${join("", aws_lb.deploy_public.*.arn_suffix)}"
  httpcode_target_5xx_count_threshold = "${local.alb_httpcode_target_5xx_count_threshold}"
  httpcode_elb_5xx_count_threshold    = "${local.alb_httpcode_elb_5xx_count_threshold}"
}

# Outputs
# --------------------------------------------------------------

output "deploy_elb_dns_name" {
  value       = "${join("", aws_elb.deploy_elb.*.dns_name)}"
  description = "DNS name to access the deploy service"
}

output "deploy_alb_dns_name" {
  value       = "${join("", aws_lb.deploy_public.*.dns_name)}"
  description = "DNS name to access the deploy service"
}
