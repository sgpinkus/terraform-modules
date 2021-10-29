variable "region" {
  type = string
  default = "us-west-2"
  description = "The AWS Region to provision resources in"
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "name" {
  description = "Used to name resources that take a name or name prefix"
}

variable "common_tags" {
  default = {}
}

variable "custom_instance_tags" {
  default = {}
}

variable "custom_volume_tags" {
  default = {}
}

variable "image_id" {
  type = string
  default = ""
  description = "If not set an Amazon Linux 2 image will be used. Module assumes image is Amazon Linux derived."
}

variable "instance_type" {
  default = "t3a.micro"
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

variable "ingress_rules" {
  type = list(object({
    protocol = string
    from_port = number
    to_port = number
    description = optional(string)
    cidr_blocks = optional(list(string))
    ipv6_cidr_blocks = optional(list(string))
    security_groups = optional(list(string))
  }))
  default = [
    {
      description = ""
      protocol = "tcp"
      from_port = 22
      to_port = 22
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

variable "egress_rules" {
  type = list(object({
    protocol = string
    from_port = number
    to_port = number
    description = optional(string)
    cidr_blocks = optional(list(string))
    ipv6_cidr_blocks = optional(list(string))
    security_groups = optional(list(string))
  }))
  default = [
    {
      description = ""
      protocol = "-1"
      from_port = 0
      to_port = 0
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

variable "security_group_ids" {
  default = []
  description = "Additional security groups."
}

variable "status_check_failed_action_arns" {
  default = []
  description = "Additional ARNs of things to get notified when instance status check fails."
}

variable "ebs_volume_size" {
  default = 10
}

variable "ebs_volume_device_name" {
  default = "/dev/xvdf"
}

variable "ebs_volume_snapshot_id" {
  type = string
  default = ""
}

variable "ebs_volume_mount_point" {
  default = "/data"
}

variable "additional_cloudinit_config_parts" {
  type = list(object({
    filename = string
    content_type = string
    content = string
  }))
  default = []
}
