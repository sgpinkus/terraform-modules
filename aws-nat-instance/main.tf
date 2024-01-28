data "aws_ami" "main" {
  most_recent = true
  filter {
    name = "name"
    values = ["amzn-ami-vpc-nat-*"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name = "architecture"
    values = ["x86_64"]
  }
  owners = ["137112412989"]
}

resource "aws_eip" "main" {
  vpc = true
}

resource "aws_security_group" "main" {
  name_prefix = "nat-"
  egress {
    description = ""
    protocol = "udp"
    from_port = 123
    to_port = 123
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    description = ""
    protocol = "tcp"
    from_port = 80
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    description = ""
    protocol = "tcp"
    from_port = 443
    to_port = 443
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description = ""
    protocol = "udp"
    from_port = 123
    to_port = 123
    cidr_blocks = [var.cidr_block]
  }
  ingress {
    description = ""
    protocol = "tcp"
    from_port = 80
    to_port = 80
    cidr_blocks = [var.cidr_block]
  }
  ingress {
    description = ""
    protocol = "tcp"
    from_port = 443
    to_port = 443
    cidr_blocks = [var.cidr_block]
  }
  ingress {
    description = ""
    protocol = "tcp"
    from_port = 22
    to_port = 22
    cidr_blocks = [var.cidr_block]
  }
  vpc_id = var.vpc_id
}

resource "aws_cloudwatch_log_group" "main" {
  name = "nat"
  retention_in_days = 7
  tags = var.common_tags
}

resource "aws_cloudwatch_log_group" "security" {
  name = "nat-security"
  retention_in_days = 30
  tags = var.common_tags
}

resource aws_iam_role "main" {
  name_prefix = "nat-"
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
        "Action" = ["ec2:AssociateAddress", "ec2:ModifyInstanceAttribute", "ec2:CreateRoute", "ec2:ReplaceRoute"]
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
  name_prefix = "nat-"
  role = aws_iam_role.main.name
}

resource "aws_launch_configuration" "main" { # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_configuration
  name_prefix = "nat-" # Don't specify name.
  ebs_optimized = false
  associate_public_ip_address = false
  iam_instance_profile = aws_iam_instance_profile.main.arn
  image_id = var.image_id != "" ? var.image_id : data.aws_ami.main.id
  instance_type = "t2.nano"
  key_name = var.key_name
  security_groups = [aws_security_group.main.id]
  user_data_base64 = "${data.template_cloudinit_config.main.rendered}"
  metadata_options {
    http_tokens = "required"
    http_endpoint = "enabled"
  }
  root_block_device {
    volume_type = "gp3"
    encrypted = "true"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "main" {
  name_prefix = "nat-"
  min_size = 1
  max_size = 1
  instance_refresh {
    strategy = "Rolling"
  }
  launch_configuration = aws_launch_configuration.main.name
  vpc_zone_identifier = var.subnet_ids
  tag {
    key = "Name"
    value = "nat"
    propagate_at_launch = true
  }
}
