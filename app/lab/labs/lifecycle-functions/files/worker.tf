resource "aws_launch_template" "worker" {
  name          = "orders-worker"
  image_id      = data.aws_ami.al2.id
  instance_type = var.instance_type
  user_data     = base64encode(file("${path.module}/bootstrap.sh"))

  iam_instance_profile {
    name = aws_iam_instance_profile.worker.name
  }
}

resource "aws_autoscaling_group" "worker" {
  name                = "orders-workers"
  min_size            = 1
  max_size            = 6
  desired_capacity    = 2
  vpc_zone_identifier = data.aws_subnets.default.ids

  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }
}
