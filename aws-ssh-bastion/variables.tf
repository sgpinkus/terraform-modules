variable "region" {
  type = string
  default = "us-west-2"
  description = "The AWS Region to provision resources in"
}

variable "name" {
  default = "bastion"
  description = "Used to name resources that take a name or name prefix"
}

variable "common_tags" {
  default = {}
}

variable "enabled_metrics" { # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#enabled_metrics
  default = ["GroupInServiceInstances", "GroupPendingInstances", "GroupTerminatingInstances", "GroupTotalInstances"]
}

variable "image_id" {
  type = string
  default = ""
  description = "If not set an Amazon Linux 2 image will be used. Module assumes image is Amazon Linux derived."
}

variable "eip_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}

variable "key_name" {
  type = string
}

variable "ec2user_password" {
  type = string
}

variable "ssh_port" {
  type = number
  default = 22
}

variable "security_group_ids" {
  default = []
  description = "Additional security groups."
}
