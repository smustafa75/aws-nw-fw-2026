# ── Application Load Balancer ─────────────────────────────────────────────────
# Internet-facing ALB in the dedicated ALB VPC public subnets.
# Targets are EC2 private IPs in VPC A — must use ip target type (cross-VPC).
resource "aws_lb" "this" {
  name               = var.name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  tags = { Name = var.name }
}

# ── Target Group ──────────────────────────────────────────────────────────────
# ip target type required — EC2 instances are in a different VPC.
# Health check on /index.html port 80 — httpd must be running on targets.
resource "aws_lb_target_group" "this" {
  name        = "${var.name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/index.html"
    protocol            = "HTTP"
    port                = "80"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }

  tags = { Name = "${var.name}-tg" }
}

# ── Listener ──────────────────────────────────────────────────────────────────
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# ── Target Registrations ──────────────────────────────────────────────────────
# Register each EC2 private IP from VPC A into the target group.
resource "aws_lb_target_group_attachment" "this" {
  count            = length(var.target_ips)
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = var.target_ips[count.index]
  port             = 80
}
