variable "instances" {
  type = map(object({
    instance_type = optional(string, "t3.micro")
    subnet_index  = optional(number, 0)
    tags          = optional(map(string), {})
  }))
}
