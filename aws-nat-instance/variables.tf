variable "region" {
  type = string
  default = "us-west-2"
  description = "The AWS Region to provision resources in"
}

variable "common_tags" {
  default = {}
}

variable "ec2user_password" {
  type = string
}

variable "cidr_block" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}

variable "image_id" {
  type = string
  default = ""
}

variable "key_name" {
  type = string
}

variable "ssh_port" {
  type = number
  default = 22
}

variable "route_table_id" {
  type = string
}
