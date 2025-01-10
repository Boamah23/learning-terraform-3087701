output "environment_url" {
    value = module.web_alb.dns_name
}

output "target_groups" {
  value = aws_lb_target_group.this
}