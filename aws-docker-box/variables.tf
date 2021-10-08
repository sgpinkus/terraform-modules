variable "region" {
  type = string
  description = "The AWS Region to provision resources in"
}

variable "name" {
}

variable "common_tags" {
  type = map(string)
  default = {}
}

variable "image_id" {
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
  default = []
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

variable root_block_device {
  type = object({
    volume_size = optional(number)
    volume_type = optional(string)
    encrypted = optional(bool)
  })
  default = {
    volume_size = 30
    volume_type = "gp3"
    encrypted = "true"
  }
}
