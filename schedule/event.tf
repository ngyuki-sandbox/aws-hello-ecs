////////////////////////////////////////////////////////////////////////////////
// CloudWatch Event

resource "aws_cloudwatch_event_rule" "ecs" {
  name                = "${var.tag}-ecs"
  schedule_expression = "cron(* * * * ? *)"
}

resource "aws_cloudwatch_event_target" "ecs" {
  target_id = "${var.tag}-ecs"
  rule      = aws_cloudwatch_event_rule.ecs.name
  arn       = aws_ecs_cluster.cluster.arn
  role_arn  = aws_iam_role.event.arn

  ecs_target {
    launch_type      = "FARGATE"
    platform_version = "LATEST"

    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.task.arn

    network_configuration {
      subnets          = data.aws_subnet_ids.default.ids
      security_groups  = [data.aws_security_group.default.id]
      assign_public_ip = true
    }
  }

  input = jsonencode({
    "containerOverrides" : [
      {
        "name" : "app",
        "command" : ["php", "-v"]
      }
    ]
  })
}
