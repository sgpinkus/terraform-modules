data "template_cloudinit_config" "main" { // https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/cloudinit_config
  gzip          = true
  base64_encode = true

  part {
    filename = "files.cfg"
    content_type = "text/cloud-config"
    content = <<-EOF
      hostname: docker-box
      write_files:
      - path: /etc/awslogs/awscli.conf
        content: ${base64encode(templatefile("${path.module}/assets/awscli.conf.tmpl", { region = var.region }))}
        encoding: b64
        owner: root:root
        permissions: '0400'
      - path: /etc/awslogs/awslogs.conf
        content: ${base64encode(templatefile("${path.module}/assets/awslogs.conf.tmpl", { log_group_name = aws_cloudwatch_log_group.main.name, security_log_group_name = aws_cloudwatch_log_group.security.name }))}
        encoding: b64
        owner: root:root
        permissions: '0400'
      - path: /etc/audit/rules.d/audit.rules
        content: ${base64encode(file("${path.module}/assets/audit.rules"))}
        encoding: b64
        owner: root:root
        permissions: '0644'
    EOF
  }
  part {
    filename = "0-eip.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
    TOKEN=$(curl --silent --max-time 60 -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 30")
    INSTANCEID=$(curl --silent --max-time 60 -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
    PRIVATE_IP=$(curl --max-time 60 -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
    echo $INSTANCEID $PRIVATE_IP
    EOF
  }
  part {
    filename = "0-chattr.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
      chattr +i /etc/awslogs/awscli.conf # Something is changing this file with broken config.
    EOF
  }
  part {
    # More reliabe than cloud-init packages and yum_repos etc modules ...
    filename = "1-packages.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
      amazon-linux-extras install epel -y
      yum update -y
      yum install yum-cron audit awslogs -y
      systemctl enable yum-cron awslogsd
      systemctl restart awslogsd
    EOF
  }
  part {
    filename = "2-yum.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
      sed -r 's/update_cmd = .*/update_cmd = minimal-security-severity:Important/' /etc/yum/yum-cron.conf -i
    EOF
  }
  part {
    filename = "3-auditd.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
      sed -i -r 's/log_format\\s*=.*/log_format = ENRICHED/;s/name_format\\s*=.*/name_format = hostname/' /etc/audit/auditd.conf
      augenrules --load
      service auditd restart
    EOF
  }
  part {
    filename = "4-users.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
      sed -i -r "s/ec2-user ALL=\(ALL\) NOPASSWD:ALL/ec2-user ALL=(ALL) ALL/"  /etc/sudoers.d/90-cloud-init-users
      echo "${var.ec2user_password}" | passwd ec2-user -f --stdin
    EOF
  }
  part {
    filename = "7-base-final.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
      systemctl status yum-cron auditd awslogsd || true
    EOF
  }
  part {
    # More reliabe than cloud-init packages and yum_repos etc modules ...
    filename = "10-docker-packages.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
      amazon-linux-extras install epel -y
      yum install docker -y
      systemctl enable docker
      systemctl restart awslogsd
    EOF
  }
  part {
    # More reliabe than cloud-init packages and yum_repos etc modules ...
    filename = "11-docker-compose.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
      sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
      sudo chmod +x /usr/local/bin/docker-compose
    EOF
  }
}
