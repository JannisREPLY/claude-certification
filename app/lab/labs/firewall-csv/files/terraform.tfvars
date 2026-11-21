environment = "prod"
admin_cidr  = "10.20.0.0/16"

instances = {
  web-a = {
    instance_type     = "t3.micro"
    availability_zone = "us-east-1a"
  }
  web-b = {
    instance_type     = "t3.small"
    availability_zone = "us-east-1b"
  }
}
