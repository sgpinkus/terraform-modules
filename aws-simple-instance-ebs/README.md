Creates a by default Amazon Linux 2 instance configured with a EBS volume attached and basic health check plus reboot action.

    module "pi" {
      source = "./my-terraform-modules/aws-simple-instance-ebs/"
      name = "pi"
      common_tags = var.common_tags
      ec2user_password = var.ec2user_password
      key_name = var.bastion_key_name
      region = local.region
      ssh_port = 12322
      subnet_id = module.vpc.public_subnets[0]
      vpc_id = module.vpc.vpc_id
      status_check_failed_action_arns = [aws_sns_topic.alerts.arn]
    }
