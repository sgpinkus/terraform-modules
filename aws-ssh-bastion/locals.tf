# TODO: Use an aws_ami data source. This is more predicatable but harder to maintain.
locals {
  general_purpose_ami_map = {
    "ap-south-1" = "ami-04db49c0fb2215364"
    "ap-northeast-2" = "ami-0a0de518b1fc4524c"
    "ap-northeast-1" = "ami-09ebacdc178ae23b7"
    "ap-east-1" = "ami-0a2115f8cc0a3956b"
    "ap-southeast-1" = "ami-0f511ead81ccde020"
    "ap-southeast-2" = "ami-0aab712d6363da7f9"
    "us-east-1" = "ami-0c2b8ca1dad447f8a"
    "us-east-2" = "ami-0443305dabd4be2bc"
    "us-west-1" = "ami-04b6c97b14c54de18"
    "us-west-2" = "ami-083ac7c7ecf9bb9b0"
  }
  name_prefix = "${var.name}-"
}
