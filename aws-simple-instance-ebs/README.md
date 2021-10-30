Creates a by default Amazon Linux 2 instance configured with a EBS volume attached and basic health check plus reboot action.

A pretty complex example scenario: A single instance with docker-compose installed and a public IP attached. Global SSH access on the default port 22. Start a docker-compose app. Probably still not super reliable. Application based health checks would be needed as next step - should be pretty easy to add via lambda and custom metric.

```
resource "aws_eip" "box" {
  vpc = true
}

resource "aws_route53_record" "box" {
  zone_id = aws_route53_zone.public.zone_id
  name    = "box.${var.vpc_name}.${terraform.workspace}.exmpla.com"
  type    = "A"
  ttl     = "300"
  records = [aws_eip.box.public_ip]
}

module "box" {
  source = "./my-terraform-modules/aws-simple-instance-ebs"
  name = "test-box"
  subnet_id = module.vpc.public_subnets[0]
  vpc_id = module.vpc.vpc_id
  region = local.region
  instance_type = "t3a.medium"
  common_tags = var.common_tags
  image_id = "ami-05c029a4b57edda9e"
  key_name = "dev-ext-key"
  ebs_volume_size = 15
  ec2user_password = var.ec2user_password
  ingress_rules = [
    {
      description = "SSH"
      protocol = "tcp"
      from_port = 22
      to_port = 22
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "Web app"
      protocol = "tcp"
      from_port = 80
      to_port = 80
      cidr_blocks = ["0.0.0.0/0"]
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
  additional_cloudinit_config_parts = [
    {
      filename = "200-eip.sh"
      content_type = "text/x-shellscript"
      content = <<-EOF
      TOKEN=$(curl --silent --max-time 60 -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 30")
      INSTANCEID=$(curl --silent --max-time 60 -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
      aws --region ${local.region} ec2 associate-address --instance-id $INSTANCEID --allocation-id ${aws_eip.box.id}
      EOF
    },
    {
      # More reliabe than cloud-init packages and yum_repos etc modules ...
      filename = "201-docker-compose.sh"
      content_type = "text/x-shellscript"
      content = <<-EOF
        amazon-linux-extras install epel -y
        yum install docker -y
        systemctl enable docker
        systemctl start docker
        curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        usermod -aG docker ec2-user
      EOF
    },
    {
      # More reliabe than cloud-init packages and yum_repos etc modules ...
      filename = "203-docker-my-app.sh"
      content_type = "text/x-shellscript"
      content = <<-EOF
        mkdir /root/my-app/
        cat >/root/my-app/docker-compose.yml <<XEOF
        version: '3'
        services:
          myservice:
            image: nginx:latest
            ports:
              - 80:80
            healthcheck:
              test: curl -fsSL http://127.0.0.1:80 || exit 1
              start_period: 15s
              interval: 30s
              timeout: 5s
              retries: 3
            restart: always
            logging:
              driver: awslogs
              options:
                awslogs-region: ap-southeast-2
                awslogs-create-group: "true"
                awslogs-group: test-box
                awslogs-stream: my-app
        XEOF
        docker-compose -f /root/my-app/docker-compose.yml up -d
      EOF
    }
  ]
}
```
