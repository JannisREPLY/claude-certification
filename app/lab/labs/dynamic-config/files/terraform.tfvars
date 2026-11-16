environment = "dev"

subnets = {
  web = { cidr = "10.50.1.0/24", public = true }
  app = { cidr = "10.50.2.0/24" }
  db  = { cidr = "10.50.3.0/24" }
}

ingress_ports = [80, 443]
