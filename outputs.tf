#output "instance_ami" {
#  value = aws_instance.web.ami
#}

output "instance_arn" {
  value = autoscaling.autoscaling_group_target_group_arns
}
