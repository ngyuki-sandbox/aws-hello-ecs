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
    subnets          = [for x in aws_subnet.back : x.id]
    security_groups  = [aws_security_group.back.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.http.arn
    container_name   = "app"
    container_port   = 80
  }

  // TargetGroup が LB にアタッチされたあとでなければならない
  depends_on = [aws_lb_listener.http]
}
