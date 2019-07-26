/**
* ## Project: app-mysql-xtrabackups
*
* Creates S3 bucket for mysql xtrabackups
*
* Migrated from:
* https://github.com/alphagov/govuk-terraform-provisioning/tree/master/old-projects/mysql_xtrabackups
*/
variable "aws_region" {
  type        = "string"
  description = "AWS region"
  default     = "eu-west-1"
}

variable "aws_replica_region" {
  type        = "string"
  description = "AWS region"
  default     = "eu-west-2"
}

variable "stackname" {
  type        = "string"
  description = "Stackname"
}

variable "aws_environment" {
  type        = "string"
  description = "AWS Environment"
}

variable "bucket_name" {
  type    = "string"
  default = "govuk-mysql-xtrabackups"
}

variable "team" {
  type    = "string"
  default = "Infrastructure"
}

variable "username" {
  type    = "string"
  default = "govuk-mysql-xtrabackups"
}

variable "versioning" {
  type    = "string"
  default = "true"
}

variable "lifecycle" {
  type    = "string"
  default = "true"
}

variable "days_to_keep" {
  type    = "string"
  default = 91
}

variable "create_env_sync_resources" {
  type        = "string"
  description = "Create users and policies used to sync data between environments."
  default     = false
}

# Resources
# --------------------------------------------------------------

terraform {
  backend          "s3"             {}
  required_version = "= 0.11.14"
}

provider "aws" {
  region  = "${var.aws_region}"
  version = "2.16.0"
}

provider "aws" {
  region  = "${var.aws_replica_region}"
  alias   = "aws_replica"
  version = "2.16.0"
}

resource "aws_s3_bucket" "bucket" {
  bucket = "${var.bucket_name}-${var.aws_environment}"
  acl    = "private"

  tags {
    Environment = "${var.aws_environment}"
    Team        = "${var.team}"
  }

  versioning {
    enabled = "${var.versioning}"
  }

  lifecycle_rule {
    prefix  = ""
    enabled = "${var.lifecycle}"

    transition {
      storage_class = "STANDARD_IA"
      days          = 30
    }

    transition {
      storage_class = "GLACIER"
      days          = 90
    }

    expiration {
      days                         = "${var.days_to_keep}"
      expired_object_delete_marker = false
    }
  }

  replication_configuration {
    role = "${aws_iam_role.govuk_mysql_xtrabackups_replication_role.arn}"

    rules {
      id     = "govuk-mysql-xtrabackups-replication-whole-bucket-rule"
      prefix = ""
      status = "Enabled"

      destination {
        bucket        = "${aws_s3_bucket.govuk-mysql-xtrabackups-replica.arn}"
        storage_class = "STANDARD"
      }
    }
  }

}

resource "aws_iam_policy" "readwrite_policy" {
  name        = "${var.bucket_name}_${var.username}-policy"
  description = "${var.bucket_name} allows writes"
  policy      = "${data.aws_iam_policy_document.readwrite_policy.json}"
}

resource "aws_iam_user" "iam_user" {
  name = "${var.username}"
}

resource "aws_iam_policy_attachment" "iam_policy_attachment" {
  name       = "${var.bucket_name}_${var.username}_attachment_policy"
  users      = ["${aws_iam_user.iam_user.name}"]
  policy_arn = "${aws_iam_policy.readwrite_policy.arn}"
}

# env_sync resources
# -----------------------------------------------

resource "aws_iam_user" "env_sync_staging" {
  count = "${var.create_env_sync_resources}"
  name  = "govuk-mysql-xtrabackups-env-sync-to-staging"
}

resource "aws_iam_user" "env_sync_integration" {
  count = "${var.create_env_sync_resources}"
  name  = "govuk-mysql-xtrabackups-env-sync-to-integration"
}

resource "aws_iam_policy" "env_sync_policy" {
  count       = "${var.create_env_sync_resources}"
  name        = "govuk-mysql-xtrabackups_env-sync-policy"
  description = "Allows read-only access to Production bucket for environment sync"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::govuk-mysql-xtrabackups-${var.aws_environment}"
    },
    {
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::govuk-mysql-xtrabackups-${var.aws_environment}/*"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "env_sync_policy_attachment" {
  count = "${var.create_env_sync_resources}"
  name  = "env_sync_policy_attachment"

  users = [
    "${aws_iam_user.env_sync_staging.name}",
    "${aws_iam_user.env_sync_integration.name}",
  ]

  policy_arn = "${aws_iam_policy.env_sync_policy.arn}"
}

resource "aws_s3_bucket" "govuk-mysql-xtrabackups-replica" {
  bucket   = "govuk-${var.aws_environment}-mysql-xtrabackups-replica"
  region   = "${var.aws_replica_region}"
  provider = "aws.aws_replica"

  tags {
    Name            = "govuk-${var.aws_environment}-mysql-xtrabackups-replica"
    aws_environment = "${var.aws_environment}"
  }

  versioning {
    enabled = true
  }
}

# S3 backup replica role configuration
data "template_file" "s3_govuk_mysql_xtrabackups_replication_role_template" {
  template = "${file("${path.module}/../../policies/s3_govuk_mysql_xtrabackups_replication_role.tpl")}"
}

# Adding backup replication role
resource "aws_iam_role" "govuk_mysql_xtrabackups_replication_role" {
  name               = "${var.stackname}-mysql-xtrabackups-replication-role"
  assume_role_policy = "${data.template_file.s3_govuk_mysql_xtrabackups_replication_role_template.rendered}"
}
