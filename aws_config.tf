# Generate s3 BucketPolicy
data "aws_iam_policy_document" "s3-config_policy" {
    statement {
        sid = "AWSConfigBucketPermissionsCheck"
  	    effect = "Allow"
        principals = {
            type = "Service"
            identifiers = ["config.amazonaws.com",]
        }
        actions = ["s3:GetBucketAcl"]
        resources = ["arn:aws:s3:::awslogs-config-${data.aws_caller_identity.current.account_id}"]
    }
    statement {
        sid = "AWSConfigBucketDelivery"
        effect = "Allow"
        principals = {
            type = "Service"
            identifiers = ["config.amazonaws.com",]
        }
        actions = ["s3:PutObject"]
        resources = ["arn:aws:s3:::awslogs-config-${data.aws_caller_identity.current.account_id}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"]
        condition = {
            test = "StringLike"
            variable = "s3:x-amz-acl" 
            values = ["bucket-owner-full-control"]
        }
    }
}

# Create s3 Bucket
resource "aws_s3_bucket" "s3-config" {
  bucket        = "awslogs-config-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  policy        = "${data.aws_iam_policy_document.s3-config_policy.json}"

  lifecycle_rule {
    id = "configLogsLifeCycle"
    enabled = true
    expiration {
      days = "${var.config-expired-day}"
    }
  }
}

## Create IAM Role
resource "aws_iam_role" "config-role" {
  name               = "config-role-${var.region}"
  assume_role_policy = "${data.aws_iam_policy_document.config-role-data.json}"
}
resource "aws_iam_role_policy_attachment" "config-rolepolicy-attach" {
  role       = "${aws_iam_role.config-role.id}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRole"
}

# Generate IAM AssumeRole Policy 
data "aws_iam_policy_document" "config-role-data" {
    statement {
  	    effect = "Allow"
        principals = {
            type        = "Service"
            identifiers = ["config.amazonaws.com"]
        }
        actions = ["sts:AssumeRole"]
    }
}

# Create ConfigurationRecorder
resource "aws_config_configuration_recorder" "config-cnfrec" {
    name     = "configuration-recorder-${var.region}"
    role_arn = "${aws_iam_role.config-role.arn}"
    recording_group {
        all_supported = true
        include_global_resource_types = true
    }
}

# Create DeliveryChannel
resource "aws_config_delivery_channel" "config-cdc" {
    s3_bucket_name = "${aws_s3_bucket.s3-config.bucket}"
    depends_on     = ["aws_config_configuration_recorder.config-cnfrec"]
    name           = "delivery-channel-${var.region}"
    snapshot_delivery_properties {
        delivery_frequency = "One_Hour"
    }
}

# Start ConfigurationRecorder
resource "aws_config_configuration_recorder_status" "config-cnfrec-status" {
  name       = "${aws_config_configuration_recorder.config-cnfrec.name}"
  is_enabled = true
  depends_on = ["aws_config_delivery_channel.config-cdc"]
}