variable "region" {
  type = string
  default = "us-west-2"
  description = "The AWS Region to provision resources in"
}

variable "common_tags" {
  default = {}
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
