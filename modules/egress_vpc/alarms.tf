# One alarm per NAT GW (count = 2, one per AZ).

resource "aws_cloudwatch_metric_alarm" "nat_packets_drop" {
  count               = 2
  alarm_name          = "NatGwPacketsDropsAlarm_2020-04-01-az${count.index + 1}"
  alarm_description   = "NAT GW is dropping packets — possible bandwidth or connection limit"
  namespace           = "AWS/NATGateway"
  metric_name         = "PacketsDropCount"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { NatGatewayId = aws_nat_gateway.nat[count.index].id }
  tags                = { Name = "NatGwPacketsDropsAlarm_2020-04-01-az${count.index + 1}" }
}

resource "aws_cloudwatch_metric_alarm" "nat_connection_success" {
  count               = 2
  alarm_name          = "NatGwSuccessfulConnectionPercentageAlarm_2020-04-01-az${count.index + 1}"
  alarm_description   = "NAT GW successful connection percentage dropped below 95%"
  namespace           = "AWS/NATGateway"
  metric_name         = "ConnectionEstablishedCount"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 2
  threshold           = 95
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { NatGatewayId = aws_nat_gateway.nat[count.index].id }
  tags                = { Name = "NatGwSuccessfulConnectionPercentageAlarm_2020-04-01-az${count.index + 1}" }
}
