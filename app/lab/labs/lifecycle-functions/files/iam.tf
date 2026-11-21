resource "aws_iam_role" "worker" {
  name = "orders-worker"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

data "aws_iam_policy_document" "worker" {
  statement {
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage"]
    resources = ["arn:aws:sqs:us-east-1:*:orders-jobs"]
  }
}

resource "aws_iam_policy" "worker" {
  name   = "orders-worker-queue"
  policy = data.aws_iam_policy_document.worker.json
}

resource "aws_iam_role_policy_attachment" "worker" {
  role       = aws_iam_role.worker.name
  policy_arn = aws_iam_policy.worker.arn
}

resource "aws_iam_instance_profile" "worker" {
  name = "orders-worker"
  role = aws_iam_role.worker.name
}
