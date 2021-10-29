terraform {
  required_version = ">= 0.15"
  experiments = [module_variable_optional_attrs]
}

data "aws_subnet" "this" {
  id = var.subnet_id
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

resource "aws_cloudwatch_log_group" "this" {
  name = "${var.name}"
  retention_in_days = 7
  tags = var.common_tags
}

resource "aws_cloudwatch_log_group" "security" {
  name = "${var.name}-security"
  retention_in_days = 30
  tags = var.common_tags
}

resource aws_iam_role "this" {
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
    name = "ec2"
    policy = jsonencode({
      "Version" = "2012-10-17"
      "Statement" = [{
        "Effect" = "Allow"
        "Action" = [
          "ec2:AssociateAddress",
          "ec2:Describe*",
          "ec2:AttachNetworkInterface",
          "ec2:AttachVolume",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:RunInstances",
          "ec2:StartInstances",
          "ec2:DeleteVolume",
          "ec2:CreateSnapshot",
        ],
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
          aws_cloudwatch_log_group.this.arn,
          aws_cloudwatch_log_group.security.arn,
          "${aws_cloudwatch_log_group.this.arn}:*",
          "${aws_cloudwatch_log_group.security.arn}:*"
        ]
      }]
    })
  }
}

resource "aws_iam_instance_profile" "this" {
  name_prefix = "${var.name}-"
  role = aws_iam_role.this.name
}

resource "aws_ebs_volume" "this" {
  availability_zone = data.aws_subnet.this.availability_zone
  size = var.ebs_volume_size
  type = "gp3"
  snapshot_id = var.ebs_volume_snapshot_id
  tags = merge(
    { Name = var.name },
    var.custom_volume_tags
  )
  lifecycle {
    create_before_destroy = true
    prevent_destroy = false
  }
}

resource "aws_network_interface" "this" {
  subnet_id = data.aws_subnet.this.id
  security_groups = [aws_security_group.this.id]
}

resource "aws_instance" "this" {
  ami = coalesce(var.image_id, local.general_purpose_ami_map[var.region])
  instance_type = var.instance_type
  key_name = var.key_name
  iam_instance_profile = aws_iam_instance_profile.this.name
  user_data_base64 = "${data.template_cloudinit_config.this.rendered}"
  tags = merge(
    { Name = var.name },
    var.custom_instance_tags
  )
  network_interface {
    network_interface_id = aws_network_interface.this.id
    device_index         = 0
  }
  credit_specification {
    cpu_credits = "unlimited"
  }
}

resource "aws_volume_attachment" "this" {
  device_name = var.ebs_volume_device_name
  volume_id   = aws_ebs_volume.this.id
  instance_id = aws_instance.this.id
}

resource "aws_cloudwatch_metric_alarm" "ec2_system" {
  # This means whp something is wrong with AWS's infrastructure. AWS should just do this recovery by default.
  alarm_name = "${var.name}-system-check-failed-alarm-${aws_instance.this.id}"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "5"
  metric_name               = "StatusCheckFailed_System"
  namespace                 = "AWS/EC2"
  period                    = "60"
  statistic                 = "Minimum"
  threshold                 = "0"
  alarm_description         = "EC2 Autorecovery for Node Instance. Autorecover if we fail EC2 system status checks for 5 minutes."
  alarm_actions = concat(["arn:aws:automate:${var.region}:ec2:recover"], var.status_check_failed_action_arns)
  insufficient_data_actions = []
  dimensions = {
    InstanceId = aws_instance.this.id
  }
}

resource "aws_cloudwatch_metric_alarm" "ec2_instance" {
  # Instance is not reachable via a ~ping.
  alarm_name = "${var.name}-instance-check-failed-alarm-${aws_instance.this.id}"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "5"
  metric_name               = "StatusCheckFailed_Instance"
  namespace                 = "AWS/EC2"
  period                    = "60"
  statistic                 = "Minimum"
  threshold                 = "0"
  alarm_description         = "EC2 Reboot for Node Instance. Autorecover if we fail EC2 instance status checks for 5 minutes."
  alarm_actions = concat(["arn:aws:automate:${var.region}:ec2:reboot"], var.status_check_failed_action_arns)
  insufficient_data_actions = []
  dimensions = {
    InstanceId = aws_instance.this.id
  }
}

resource "aws_cloudwatch_metric_alarm" "ec2_instance_cpu" {
  # If CPU is super high for super long something is probably wrong so restart.
  alarm_name = "${var.name}-instance-cpu-check-failed-alarm-${aws_instance.this.id}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "5"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = "60"
  statistic                 = "Average"
  threshold                 = "99"
  alarm_description         = "EC2 Reboot for Node Instance. Autorecover if EC2 instance cpu is unusually high for 5 minutes."
  alarm_actions = concat(["arn:aws:automate:${var.region}:ec2:reboot"], var.status_check_failed_action_arns)
  insufficient_data_actions = []
  dimensions = {
    InstanceId = aws_instance.this.id
  }
}
