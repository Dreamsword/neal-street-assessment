# -----------------------------------------------------------------------------
# CloudWatch Log Group
# The CloudWatch agent (installed by Ansible) ships logs here.
# 7-day retention keeps costs low for dev.
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.project}/${var.environment}/app"
  retention_in_days = 7

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "nginx" {
  name              = "/${var.project}/${var.environment}/nginx"
  retention_in_days = 7

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "system" {
  name              = "/${var.project}/${var.environment}/system"
  retention_in_days = 7

  tags = local.common_tags
}
