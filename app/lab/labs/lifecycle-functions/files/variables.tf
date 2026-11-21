variable "environment" {
  type    = string
  default = "prod"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "packages" {
  type    = list(string)
  default = ["jq", "amazon-cloudwatch-agent"]
}

variable "worker_ports" {
  type    = list(number)
  default = [8080, 9100]
}

variable "trusted_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/8", "192.168.0.0/16"]
}
