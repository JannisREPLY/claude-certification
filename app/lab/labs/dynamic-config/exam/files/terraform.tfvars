instances = {
  web-1 = { role = "web" }
  web-2 = { role = "web", subnet_index = 1 }
  batch = { instance_type = "t3.small", tags = { Schedule = "nightly" } }
}
