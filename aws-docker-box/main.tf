
data "aws_vpc" "this" {
  id = var.vpc_id
}

local {
  ingress_rules = [
    {
      description = ""
      protocol = "tcp"
      from_port = 0
      to_port = 65535
      cidr_blocks = [data.aws_vpc.this.cidr_block]
      # security_groups = [var.client_security_group_id]
    },
    {
      description = ""
      protocol = "tcp"
      from_port = 22
      to_port = 22
      security_groups = [var.ssh_security_group_id]
    }
  ]
}

resource "aws_security_group" "instance" {
  name_prefix = "${var.name}-"
  dynamic "ingress_rule" {
    for_each = local.ingress_rules
    content {
      description = try(ingress_rule.value.description, "")
      protocol = try(ingress_rule.value.protocol, "-1")
      from_port = ingress_rule.value.from_port
      to_port = ingress_rule.value.to_port
      cidr_blocks = try(ingress_rule.value.cidr_blocks, null)
      ipv6_cidr_blocks = try(ingress_rule.value.cidr_blocks, null)
      security_groups = try(ingress_rule.value.security_groups, null)
    }
  }
  # Need to explicitly define egress - different to CF which has default open egress.
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
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
  image_id = var.image_id == "" ? local.general_purpose_ami_map[var.region] : var.image_id
  instance_type = "t3a.medium"
  key_name = var.key_name
  metadata_options {
    http_tokens = "required"
    http_endpoint = "enabled"
  }
  root_block_device {
    volume_type = "gp3"
    encrypted = "true"
  }
  security_groups = [aws_security_group.main.id]
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
  tags = merge(var.common_tags, {
    key = "Name"
    value = var.name
    propagate_at_launch = true
  })
}