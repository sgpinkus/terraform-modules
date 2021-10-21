output "security_group_id" {
  description = "ID of the security group."
  value = aws_security_group.main.id
}

output "autoscaling_group_arn" {
  description = " The ARN for this Auto Scaling Group."
  value = aws_autoscaling_group.main.arn
}

output "autoscaling_group_id" {
  description = "The Auto Scaling Group id."
  value = aws_autoscaling_group.main.id
}

output "autoscaling_group_name" {
  description = "The name of the Auto Scaling Group."
  value = aws_autoscaling_group.main.name
}
