data "template_cloudinit_config" "this" { // https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/cloudinit_config
  gzip          = true
  base64_encode = true

  part {
    filename = "files.cfg"
    content_type = "text/cloud-config"
    content = <<-EOF
      hostname: ${var.name}
      write_files:
      - path: /etc/awslogs/awscli.conf
        content: ${base64encode(templatefile("${path.module}/assets/awscli.conf.tmpl", { region = var.region }))}
        encoding: b64
        owner: root:root
        permissions: '0400'
      - path: /etc/awslogs/awslogs.conf
        content: ${base64encode(templatefile("${path.module}/assets/awslogs.conf.tmpl", { log_group_name = aws_cloudwatch_log_group.this.name, security_log_group_name = aws_cloudwatch_log_group.security.name }))}
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
    filename = "100-chattr.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
      chattr +i /etc/awslogs/awscli.conf # Something is changing this file with broken config.
    EOF
  }
  part {
    # More reliabe than cloud-init packages and yum_repos etc modules ...
    filename = "101-base-packages.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
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
    filename = "106-system.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
    echo "* soft nofile 64000
    * hard nofile 64000
    * soft nproc 32000
    * hard nproc 32000" > /etc/limits.conf
    echo "vm.swappiness=5" >/etc/sysctl.d/99-swappiness.conf
    sysctl -p /etc/sysctl.d/99-swappiness.conf
    EOF
  }
  part {
    filename = "107-data-volume.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
    # blockdev --setra 32 "${var.ebs_volume_device_name}"
    # echo 'ACTION=="add", KERNEL=="'$1'", ATTR{bdi/read_ahead_kb}="16"' | tee /etc/udev/rules.d/85-ebs.rules
    if [[ -z "${var.ebs_volume_snapshot_id}" ]]; then
      mkfs.xfs -f "${var.ebs_volume_device_name}"
    fi
    if ! egrep "^${var.ebs_volume_device_name}" /etc/fstab -q; then
      echo "${var.ebs_volume_device_name} ${var.ebs_volume_mount_point} xfs defaults,auto,noatime,noexec 0 0" | tee -a /etc/fstab
    fi
    mkdir -p ${var.ebs_volume_mount_point}
    mount ${var.ebs_volume_mount_point}
    EOF
  }
  part {
    filename = "108-base-final.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
      systemctl status yum-cron auditd awslogsd fail2ban firewalld || true
    EOF
  }
  # Custom parts. These are run in lexographical order of filename. It's upto user to set filename properly.
  dynamic "part" {
    for_each = var.additional_cloudinit_config_parts
    content {
      filename = part.value.filename
      content_type = part.value.content_type
      content = part.value.content
    }
  }
}
