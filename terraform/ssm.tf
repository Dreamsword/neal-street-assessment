# -----------------------------------------------------------------------------
# SSM Parameter Store — demo application secret
# In real life this value would be set out-of-band (console, CLI, or CI),
# never hardcoded in Terraform. We use a placeholder here to show the pattern.
#
# Why SSM over Secrets Manager?
# - SSM Parameter Store (Standard tier) is free
# - Secrets Manager costs $0.40/secret/month + $0.05 per 10K API calls
# - For a demo secret, SSM is the right choice
# -----------------------------------------------------------------------------
resource "aws_ssm_parameter" "app_secret" {
  name  = "/${var.project}/${var.environment}/APP_SECRET"
  type  = "SecureString"
  value = "CHANGE_ME_AFTER_DEPLOY"

  tags = local.common_tags

  lifecycle {
    ignore_changes = [value]
  }
}
