Creates a by default Amazon Linux 2 instance in a single node ASG so it will automatically restarted and this can be monitored. Create two log groups: One for generic logs and one for logs to do with security to allow the security logs to be filtered more easily.

Example:

      module "docker_box" {
        source = "./aws-docker-box"
        name = "docker-box"
        common_tags = var.common_tags
        ec2user_password = var.ec2user_password
        image_id = "ami-05c029a4b57edda9e" # aws ec2 describe-images --filters "Name=owner-id,Values=137112412989" "Name=architecture,Values=x86_64" "Name=root-device-name,Values=/dev/xvda" "Name=name,Values=amzn2-ami-hvm-2*" "Name=description,Values=Amazon Linux 2 AMI 2.0.202110*" | jq '.Images | map({ Description, ImageId })'
        key_name = "itrazo-dev-int-key"
        region = local.region
        subnet_ids = module.vpc.private_subnets
        vpc_id = module.vpc.vpc_id
        ingress_rules = [
          {
            description = "SSH Bastion"
            protocol = "tcp"
            from_port = 22
            to_port = 22
            cidr_blocks = ["0.0.0.0/0"]
            security_group_ids = [module.ssh_bastion.security_group_id]
          },
          {
            description = "VPC any (TODO: tighten)"
            protocol = "tcp"
            from_port = 0
            to_port = 65535
            cidr_blocks = [module.vpc.vpc_cidr_block]
            # security_group_ids = [client_security_group_id]
          }
        ]
      }
