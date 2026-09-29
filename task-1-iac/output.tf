output "resource_output" {
  value = {
    "vpc_id"                             = aws_vpc.main.id
    "application_load_balancer_dns_name" = aws_lb.main.dns_name
    "autoscaling_group_name"             = aws_autoscaling_group.app_asg.name
    "target_group_arn"                   = aws_lb_target_group.app_tg.arn
  }
}