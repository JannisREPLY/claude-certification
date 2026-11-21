instances = {
  web-1 = {}
  web-2 = { subnet_index = 1 }
  batch = { instance_type = "t3.small", tags = { Schedule = "nightly" } }
}
