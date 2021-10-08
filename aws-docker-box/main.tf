terraform {
  required_version = ">= 0.15"
  experiments = [module_variable_optional_attrs]
}

data "aws_vpc" "this" {
  id = var.vpc_id
}

resource "aws_security_group" "this" {
  name_prefix = "${var.name}-"
  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      protocol = ingress.value.protocol
      from_port = ingress.value.from_port
      to_port = ingress.value.to_port
      description = ingress.value.description
      cidr_blocks = ingress.value.cidr_blocks
      ipv6_cidr_blocks = ingress.value.ipv6_cidr_blocks
      security_groups = ingress.value.security_groups
    }
  }
  # Need to explicitly define egress - different to CF which has default open egress.
  dynamic "egress" {
    for_each = var.egress_rules
    content {
      protocol = egress.value.protocol
      from_port = egress.value.from_port
      to_port = egress.value.to_port
      description = egress.value.description
      cidr_blocks = egress.value.cidr_blocks
      ipv6_cidr_blocks = egress.value.ipv6_cidr_blocks
      security_groups = egress.value.security_groups
    }
  }
  vpc_id = var.vpc_id
}

resource "aws_cloudwatch_log_group" "main" {
  name = var.name
  retention_in_days = 7
  tags = var.common_tags
}

resource "aws_cloudwatch_log_group" "security" {
  name = "${var.name}-security"
  retention_in_days = 30
  tags = var.common_tags
}

resource aws_iam_role "main" {
  name_prefix = "${var.name}-"
  force_detach_policies = true
  assume_role_policy = jsonencode({
    "Version" = "2012-10-17"
    "Statement" = [{
      "Effect" = "Allow"
      "Action" = ["sts:AssumeRole"],
      "Principal" = { "Service" = "ec2.amazonaws.com" }
    }]
  })
  managed_policy_arns = []
  inline_policy {
    name = "logs"
    policy = jsonencode({
      "Version" = "2012-10-17"
      "Statement" = [{
        "Effect" = "Allow"
        "Action" = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        "Resource" = [
          aws_cloudwatch_log_group.main.arn,
          aws_cloudwatch_log_group.security.arn,
          "${aws_cloudwatch_log_group.main.arn}:*",
          "${aws_cloudwatch_log_group.security.arn}:*"
        ]
      }]
    })
  }
}

resource "aws_iam_instance_profile" "main" {
  name_prefix = "${var.name}-"
  role = aws_iam_role.main.name
}

resource "aws_launch_configuration" "main" { # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_configuration
  name_prefix = "${var.name}-" # Don't specify name.
  ebs_optimized = false
  associate_public_ip_address = false
  iam_instance_profile = aws_iam_instance_profile.main.arn
  image_id = var.image_id # == "" ? local.general_purpose_ami_map[var.region] : var.image_id
  instance_type = "t3a.medium"
  key_name = var.key_name
  metadata_options {
    http_tokens = "required"
    http_endpoint = "enabled"
  }
  root_block_device {
    volume_type = var.root_block_device.volume_type
    volume_size = var.root_block_device.volume_size
    encrypted = var.root_block_device.encrypted
  }
  security_groups = [aws_security_group.this.id]
  lifecycle {
    create_before_destroy = true
  }
  user_data_base64 = "${data.template_cloudinit_config.main.rendered}"
}

resource "aws_autoscaling_group" "main" {
  name_prefix = "${var.name}-"
  min_size = 1
  max_size = 1
  instance_refresh {
    strategy = "Rolling"
  }
  launch_configuration = aws_launch_configuration.main.name
  vpc_zone_identifier = var.subnet_ids
  tags = [{
    key = "Name"
    value = var.name
    propagate_at_launch = true
  }]
}
