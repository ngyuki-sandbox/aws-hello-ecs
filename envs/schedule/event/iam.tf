
resource "aws_iam_role" "event" {
  name = "${var.name}-event"

  assume_role_policy = <<EOS
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOS
}

resource "aws_iam_role_policy_attachment" "event" {
  role       = aws_iam_role.event.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceEventsRole"
}
