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

data "aws_vpc" "default" {
  default = true
}

locals {
  // Data Source だと 1b が含まれて失敗？するのでベタで定義
  availability_zones = [
    "ap-northeast-1a",
    "ap-northeast-1c",
  ]
}

data "aws_subnet_ids" "default" {
  vpc_id = "${data.aws_vpc.default.id}"
}

data "aws_security_group" "default" {
  name = "default"
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

  network_configuration = {
    subnets          = ["${data.aws_subnet_ids.default.ids}"]
    security_groups  = ["${data.aws_security_group.default.id}"]
    assign_public_ip = true
  }
}
