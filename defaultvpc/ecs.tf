////////////////////////////////////////////////////////////////////////////////
// ECS

resource "aws_ecs_task_definition" "task" {
  family                   = "${var.tag}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution.arn

  container_definitions = jsonencode([
    {
      "name" : "app",
      "image" : "nginx:alpine",
      "essential" : true,
      "environment" : [
        {
          "name" : "APP_ENV",
          "value" : "dev"
        }
      ],
      "portMappings" : [
        {
          "containerPort" : 80,
          "protocol" : "tcp"
        }
      ],
      "logConfiguration" : {
        "logDriver" : "awslogs",
        "options" : {
          "awslogs-group" : aws_cloudwatch_log_group.ecs.name,
          "awslogs-region" : data.aws_region.current.name,
          "awslogs-stream-prefix" : "app"
        }
      }
    }
  ])
}

resource "aws_ecs_cluster" "cluster" {
  name = "${var.tag}-cluster"
}

resource "aws_ecs_service" "service" {
  name            = "${var.tag}-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  launch_type     = "FARGATE"

  desired_count                      = 2
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  network_configuration {
    subnets          = data.aws_subnet_ids.default.ids
    security_groups  = [data.aws_security_group.default.id]
    assign_public_ip = true
  }
}
