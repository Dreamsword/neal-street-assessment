# -----------------------------------------------------------------------------
# IAM Role for EC2
# Allows the instance to:
# - Read SSM parameters (for APP_SECRET)
# - Write CloudWatch Logs (for observability)
# - Use SSM Session Manager (for secure access without SSH over internet)
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name = "${local.name_prefix}-ec2-role"

  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = local.common_tags
}

# SSM Session Manager — managed policy for secure shell access
resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch agent — managed policy for shipping logs and metrics
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# SSM Parameter Store read access — scoped to our project's parameters
data "aws_iam_policy_document" "ssm_read" {
  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project}/${var.environment}/*"
    ]
  }
}

resource "aws_iam_policy" "ssm_read" {
  name   = "${local.name_prefix}-ssm-read"
  policy = data.aws_iam_policy_document.ssm_read.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm_read" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.ssm_read.arn
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = local.common_tags
}
