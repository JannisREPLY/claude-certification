variable "environment" {
  type = string
}

variable "subnets" {
  type = map(object({
    cidr   = string
    public = optional(bool, false)
  }))
}

variable "ingress_ports" {
  type = list(number)
}
