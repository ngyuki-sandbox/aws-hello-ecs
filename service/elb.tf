////////////////////////////////////////////////////////////////////////////////
// ELB

resource "aws_lb" "web" {
  name               = "${var.tag}-web"
  load_balancer_type = "application"
  ip_address_type    = "ipv4"
  security_groups    = [aws_security_group.front.id]
  subnets            = [for x in aws_subnet.front : x.id]
}

resource "aws_lb_target_group" "http" {
  name        = "${var.tag}-http"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

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
  load_balancer_arn = aws_lb.web.arn
  protocol          = "HTTP"
  port              = "80"

  default_action {
    target_group_arn = aws_lb_target_group.http.arn
    type             = "forward"
  }
}

output "elb_url" {
  value = "http://${aws_lb.web.dns_name}"
}
