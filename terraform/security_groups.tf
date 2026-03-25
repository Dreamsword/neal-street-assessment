# -----------------------------------------------------------------------------
# ALB Security Group — accepts HTTP from the internet
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name_prefix = "${local.name_prefix}-alb-"
  vpc_id      = aws_vpc.main.id
  description = "Allow HTTP inbound to ALB"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-sg"
  })
}

# -----------------------------------------------------------------------------
# EC2 Security Group — only accepts traffic from the ALB
# -----------------------------------------------------------------------------
resource "aws_security_group" "ec2" {
  name_prefix = "${local.name_prefix}-ec2-"
  vpc_id      = aws_vpc.main.id
  description = "Allow HTTP from ALB and SSH for Ansible provisioning"

  # HTTP from ALB only
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "HTTP from ALB"
  }

  # SSH for Ansible — restricted to specified CIDR.
  # Note: The EC2 instance has no public IP and lives in a private subnet,
  # so this rule is only reachable from the CI runner or a bastion/VPN.
  # In production this rule would be removed entirely and replaced with
  # AWS Systems Manager Session Manager (SSM), which provides shell access
  # over HTTPS with no inbound ports required. For this exercise, SSH is
  # used because it's the standard Ansible transport and simpler to
  # demonstrate without additional SSM tooling setup.
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
    description = "SSH for Ansible provisioning (replace with SSM in prod)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ec2-sg"
  })
}
