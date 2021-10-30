data "template_cloudinit_config" "main" { // https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/cloudinit_config
  gzip          = true
  base64_encode = true

  part {
    filename = "files.cfg"
    content_type = "text/cloud-config"
    content = <<-EOF
      hostname: bastion
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
      - path: /etc/ssh/sshd_config
        content: ${base64encode(templatefile("${path.module}/assets/sshd_config.tmpl", { ssh_port = var.ssh_port }))}
        encoding: b64
        owner: root:root
        permissions: '0600'
      - path: /etc/firewalld/services/ssh.xml
        content: ${base64encode(templatefile("${path.module}/assets/firewalld-service-ssh.xml.tmpl", { ssh_port = var.ssh_port }))}
        encoding: b64
        owner: root:root
        permissions: '0600'
      - path: /etc/fail2ban/jail.local
        content: ${base64encode(templatefile("${path.module}/assets/fail2ban-jail.local.tmpl", { ssh_port = var.ssh_port }))}
        encoding: b64
        owner: root:root
        permissions: '0400'
    EOF
  }
  part {
    # More reliabe than cloud-init packages and yum_repos etc modules ...
    filename = "100-eip.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
    TOKEN=$(curl --silent --max-time 60 -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 30")
    INSTANCEID=$(curl --silent --max-time 60 -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
    aws --region ${var.region} ec2 associate-address --instance-id $INSTANCEID --allocation-id ${var.eip_id}
    EOF
  }
  part {
    # More reliabe than cloud-init packages and yum_repos etc modules ...
    filename = "101-packages.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
      chattr +i /etc/awslogs/awscli.conf # Something is changing this file with broken config.
      amazon-linux-extras install epel -y
      yum update -y
      yum install yum-cron audit awslogs fail2ban firewalld -y
      systemctl enable yum-cron awslogsd
      systemctl restart awslogsd
    EOF
  }
  part {
    filename = "102-yum.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
      sed -r 's/update_cmd = .*/update_cmd = minimal-security-severity:Important/' /etc/yum/yum-cron.conf -i
    EOF
  }
  part {
    filename = "103-auditd.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
      sed -i -r 's/log_format\\s*=.*/log_format = ENRICHED/;s/name_format\\s*=.*/name_format = hostname/' /etc/audit/auditd.conf
      augenrules --load
      service auditd restart
    EOF
  }
  part {
    filename = "104-users.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
      sed -i -r "s/ec2-user ALL=\(ALL\) NOPASSWD:ALL/ec2-user ALL=(ALL) ALL/"  /etc/sudoers.d/90-cloud-init-users
      echo "${var.ec2user_password}" | passwd ec2-user -f --stdin
      systemctl restart sshd
    EOF
  }
  part {
    filename = "105-firewall.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
      systemctl enable firewalld fail2ban
      systemctl restart firewalld
      systemctl restart fail2ban
    EOF
  }
  part {
    filename = "107-final.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
      systemctl status yum-cron auditd awslogsd fail2ban firewalld || true
    EOF
  }
}
