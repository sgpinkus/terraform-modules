resource "aws_security_group" "main" {
  name_prefix = "bastion-"
  ingress {
    description = ""
    protocol = "tcp"
    from_port = var.ssh_port
    to_port = var.ssh_port
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = ""
    protocol = "tcp"
    from_port = var.ssh_port
    to_port = var.ssh_port
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = ""
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  vpc_id = var.vpc_id
}

resource "aws_cloudwatch_log_group" "main" {
  name = "bastion"
  retention_in_days = 7
  tags = var.common_tags
}

resource "aws_cloudwatch_log_group" "security" {
  name = "bastion-security"
  retention_in_days = 30
  tags = var.common_tags
}

resource aws_iam_role "main" {
  name_prefix = "bastion-"
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
    name = "ec2"
    policy = jsonencode({
      "Version" = "2012-10-17"
      "Statement" = [{
        "Effect" = "Allow"
        "Action" = ["ec2:AssociateAddress"]
        "Resource" = "*"
      }]
    })
  }
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
  name_prefix = "bastion-"
  role = aws_iam_role.main.name
}

resource "aws_launch_configuration" "main" { # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_configuration
  name_prefix = "bastion-" # Don't specify name.
  ebs_optimized = false
  associate_public_ip_address = false
  iam_instance_profile = aws_iam_instance_profile.main.arn
  image_id = var.image_id == "" ? local.general_purpose_ami_map[var.region] : var.image_id
  instance_type = "t2.nano"
  key_name = var.key_name
  metadata_options {
    http_tokens = "required"
    http_endpoint = "enabled"
  }
  root_block_device {
    volume_type = "gp3"
    encrypted = "true"
  }
  security_groups = concat([aws_security_group.main.id], var.security_group_ids)
  lifecycle {
    create_before_destroy = true
  }
  user_data_base64 = "${data.template_cloudinit_config.main.rendered}"
}

resource "aws_autoscaling_group" "main" {
  name_prefix = "bastion-"
  min_size = 1
  max_size = 1
  instance_refresh {
    strategy = "Rolling"
  }
  launch_configuration = aws_launch_configuration.main.name
  vpc_zone_identifier = var.subnet_ids
  tag {
    key = "Name"
    value = "bastion"
    propagate_at_launch = true
  }
}
