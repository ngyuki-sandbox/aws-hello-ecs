////////////////////////////////////////////////////////////////////////////////
// AWS

provider "aws" {
  region = "ap-northeast-1"
}

data "aws_region" "current" {}

////////////////////////////////////////////////////////////////////////////////
// IAM

resource "aws_iam_role" "execution" {
  name = "hello-ecs-execution"

  assume_role_policy = <<EOS
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOS
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = "${aws_iam_role.execution.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

////////////////////////////////////////////////////////////////////////////////
// VPC

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "hello-ecs"
  }
}

locals {
  availability_zones = [
    "ap-northeast-1a",
    "ap-northeast-1c",
  ]
}

resource "aws_subnet" "front" {
  count             = "${length(local.availability_zones)}"
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "${cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)}"
  availability_zone = "${local.availability_zones[count.index]}"

  tags = {
    Name = "hello-ecs-front"
  }
}

resource "aws_subnet" "back" {
  count             = "${length(local.availability_zones)}"
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "${cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + length(local.availability_zones))}"
  availability_zone = "${local.availability_zones[count.index]}"

  tags = {
    Name = "hello-ecs-back"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "hello-ecs"
  }
}

resource "aws_eip" "nat" {
  count = "${length(local.availability_zones)}"
  vpc   = true

  tags = {
    Name = "hello-ecs"
  }
}

resource "aws_nat_gateway" "ngw" {
  count         = "${length(local.availability_zones)}"
  subnet_id     = "${element(aws_subnet.front.*.id, count.index)}"
  allocation_id = "${element(aws_eip.nat.*.id, count.index)}"

  tags = {
    Name = "hello-ecs"
  }
}

resource "aws_route" "main" {
  route_table_id         = "${aws_vpc.main.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.igw.id}"
}

resource "aws_route_table" "back" {
  count  = "${length(local.availability_zones)}"
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "hello-ecs-back"
  }
}

resource "aws_route" "back" {
  count                  = "${length(local.availability_zones)}"
  route_table_id         = "${element(aws_route_table.back.*.id, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${element(aws_nat_gateway.ngw.*.id, count.index)}"
}

resource "aws_route_table_association" "back" {
  count          = "${length(local.availability_zones)}"
  subnet_id      = "${element(aws_subnet.back.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.back.*.id, count.index)}"
}

resource "aws_security_group" "front" {
  name        = "hello-ecs-front"
  description = "hello-ecs-front"
  vpc_id      = "${aws_vpc.main.id}"

  # http
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # local
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    self      = true
  }

  # outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "back" {
  name        = "hello-ecs-back"
  description = "hello-ecs-back"
  vpc_id      = "${aws_vpc.main.id}"

  # front
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = ["${aws_security_group.front.id}"]
  }

  # local
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    self      = true
  }

  # outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

////////////////////////////////////////////////////////////////////////////////
// ELB

resource "aws_lb" "web" {
  name               = "hello-ecs-web"
  load_balancer_type = "application"
  ip_address_type    = "ipv4"
  security_groups    = ["${aws_security_group.front.id}"]
  subnets            = ["${aws_subnet.front.*.id}"]
}

resource "aws_lb_target_group" "http" {
  name        = "hello-ecs-http"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "${aws_vpc.main.id}"

  health_check {
    protocol            = "HTTP"
    port                = 80
    path                = "/"
    matcher             = "200-399"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = "${aws_lb.web.arn}"
  protocol          = "HTTP"
  port              = "80"

  default_action {
    target_group_arn = "${aws_lb_target_group.http.arn}"
    type             = "forward"
  }
}

////////////////////////////////////////////////////////////////////////////////
// LOG

resource "aws_cloudwatch_log_group" "hello" {
  name              = "hello-ecs"
  retention_in_days = 3
}

////////////////////////////////////////////////////////////////////////////////
// ECS

resource "aws_ecs_task_definition" "hello" {
  family                   = "hello-ecs"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = "${aws_iam_role.execution.arn}"

  container_definitions = <<EOS
    [
      {
        "name": "app",
        "image": "ngyuki/hello:php",
        "essential": true,
        "environment": [{
          "name": "APP_ENV",
          "value": "dev"
        }],
        "portMappings": [
          {
            "containerPort": 80,
            "protocol": "tcp"
          }
        ],
        "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
            "awslogs-group": "${aws_cloudwatch_log_group.hello.name}",
            "awslogs-region": "${data.aws_region.current.name}",
            "awslogs-stream-prefix": "ecs"
          }
        }
      }
    ]
EOS
}

resource "aws_ecs_cluster" "hello" {
  name = "hello-ecs-cluster"
}

resource "aws_ecs_service" "hello" {
  name            = "hello-ecs-service"
  cluster         = "${aws_ecs_cluster.hello.id}"
  task_definition = "${aws_ecs_task_definition.hello.arn}"
  launch_type     = "FARGATE"

  desired_count                      = 2
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  load_balancer = {
    target_group_arn = "${aws_lb_target_group.http.arn}"
    container_name   = "app"
    container_port   = 80
  }

  network_configuration = {
    subnets          = ["${aws_subnet.back.*.id}"]
    security_groups  = ["${aws_security_group.back.id}"]
    assign_public_ip = false
  }

  // TargetGroup が LB にアタッチされたあとでなければならない
  depends_on = ["aws_lb_listener.http"]
}
