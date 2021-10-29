output "security_group_id" {
  description = "ID of the security group."
  value = aws_security_group.this.id
}

output "ebs_volume_id" {
  value = aws_ebs_volume.this.id
}
