variable "environment" {
  type = string
}

variable "allowed_cidr" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "allowed_instance_types" {
  type    = list(string)
  default = ["t3.micro", "t3.small"]
}

variable "ami_name_filter" {
  type    = string
  default = "amzn2-ami-hvm-*-x86_64-gp2"
}

variable "expected_account_id" {
  type    = string
  default = "123456789012"
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type = string
}
