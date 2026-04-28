# ALB and Target Group ARN suffixes are required for CW dimensions.
# aws_lb.arn_suffix strips the full ARN to just the loadbalancer/app/... portion.
locals {
  alb_suffix = aws_lb.this.arn_suffix
  tg_suffix  = aws_lb_target_group.this.arn_suffix
}

resource "aws_cloudwatch_metric_alarm" "elb_4xx" {
  alarm_name          = "ApplicationLoadBalancerElbHttp4xxCountAlarm_2020"
  alarm_description   = "ALB is returning 4xx errors (client errors)"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_4XX_Count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 10
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { LoadBalancer = local.alb_suffix }
  tags                = { Name = "ApplicationLoadBalancerElbHttp4xxCountAlarm_2020" }
}

resource "aws_cloudwatch_metric_alarm" "elb_5xx" {
  alarm_name          = "ApplicationLoadBalancerElbHttp5xxCountAlarm_2020"
  alarm_description   = "ALB is returning 5xx errors (ALB-generated)"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { LoadBalancer = local.alb_suffix }
  tags                = { Name = "ApplicationLoadBalancerElbHttp5xxCountAlarm_2020" }
}

resource "aws_cloudwatch_metric_alarm" "healthy_host_count" {
  alarm_name          = "ApplicationLoadBalancerHealthyHostCountAlarm_2020"
  alarm_description   = "Healthy target count dropped below 1"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  dimensions = {
    LoadBalancer = local.alb_suffix
    TargetGroup  = local.tg_suffix
  }
  tags = { Name = "ApplicationLoadBalancerHealthyHostCountAlarm_2020" }
}

resource "aws_cloudwatch_metric_alarm" "rejected_connections" {
  alarm_name          = "ApplicationLoadBalancerRejectedConnectionsCountAlarm_2020"
  alarm_description   = "ALB is rejecting connections — possible capacity or SG issue"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "RejectedConnectionCount"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { LoadBalancer = local.alb_suffix }
  tags                = { Name = "ApplicationLoadBalancerRejectedConnectionsCountAlarm_2020" }
}

resource "aws_cloudwatch_metric_alarm" "target_5xx" {
  alarm_name          = "ApplicationLoadBalancerTargetHttp5xxCountAlarm_2020"
  alarm_description   = "Targets are returning 5xx errors (application errors)"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions = {
    LoadBalancer = local.alb_suffix
    TargetGroup  = local.tg_suffix
  }
  tags = { Name = "ApplicationLoadBalancerTargetHttp5xxCountAlarm_2020" }
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_host_count" {
  alarm_name          = "ApplicationLoadBalancerUnHealthyHostCountAlarm_2020"
  alarm_description   = "One or more targets are unhealthy"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions = {
    LoadBalancer = local.alb_suffix
    TargetGroup  = local.tg_suffix
  }
  tags = { Name = "ApplicationLoadBalancerUnHealthyHostCountAlarm_2020" }
}

resource "aws_cloudwatch_metric_alarm" "target_5xx_2020" {
  alarm_name          = "ApplicationLoadBalancerTargetHttp5xxCountAlarm_2020-04-01"
  alarm_description   = "Targets are returning 5xx errors (application errors)"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions = {
    LoadBalancer = local.alb_suffix
    TargetGroup  = local.tg_suffix
  }
  tags = { Name = "ApplicationLoadBalancerTargetHttp5xxCountAlarm_2020-04-01" }
}
