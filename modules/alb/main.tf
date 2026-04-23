# ── Application Load Balancer ─────────────────────────────────────────────────
resource "aws_lb" "this" {
  name               = var.name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  tags = { Name = var.name }
}

# ── Target Group ──────────────────────────────────────────────────────────────
# vpc_id must match the ALB VPC — AWS requires ALB and TG in the same VPC.
# ip target type allows RFC-1918 addresses from other VPCs (cross-VPC via TGW).
resource "aws_lb_target_group" "this" {
  name        = "${var.name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.alb_vpc_id
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
# Target IPs are outside the ALB VPC (they are in VPC A via TGW).
# availability_zone = "all" is required when the IP is outside the TG VPC.
resource "aws_lb_target_group_attachment" "this" {
  count             = length(var.target_ips)
  target_group_arn  = aws_lb_target_group.this.arn
  target_id         = var.target_ips[count.index]
  port              = 80
  availability_zone = "all"
}
