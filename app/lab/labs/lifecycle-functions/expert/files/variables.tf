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
  default = [8080, 9100, 9200]
}

variable "trusted_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

variable "excluded_rules" {
  type    = list(string)
  default = ["9200-192.168.0.0/16", "9200-172.16.0.0/12"]
}

variable "sg_description" {
  type    = string
  default = "Orders workers"
}
