output "alb_dns_name" {
  description = "Public DNS of the ALB — hit this to reach the health endpoint"
  value       = aws_lb.main.dns_name
}

output "ec2_private_ip" {
  description = "Private IP of the web server (not directly reachable)"
  value       = aws_instance.web.private_ip
}

output "ec2_instance_id" {
  description = "Instance ID — use with SSM Session Manager for shell access"
  value       = aws_instance.web.id
}

output "cloudwatch_log_groups" {
  description = "CloudWatch Log Group names"
  value = {
    app    = aws_cloudwatch_log_group.app.name
    nginx  = aws_cloudwatch_log_group.nginx.name
    system = aws_cloudwatch_log_group.system.name
  }
}
