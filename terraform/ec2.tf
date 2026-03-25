# -----------------------------------------------------------------------------
# Look up latest Amazon Linux 2023 AMI if none specified
# -----------------------------------------------------------------------------
data "aws_ami" "al2023" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  resolved_ami = var.ami_id != "" ? var.ami_id : data.aws_ami.al2023[0].id
}

# -----------------------------------------------------------------------------
# EC2 Instance
# Sits in the private subnet, no public IP.
# Traffic arrives via ALB only.
# -----------------------------------------------------------------------------
resource "aws_instance" "web" {
  ami                    = local.resolved_ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  key_name               = var.key_name != "" ? var.key_name : null

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens   = "required" # IMDSv2 only — prevents SSRF attacks
    http_endpoint = "enabled"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-01"
    Role = "web"
  })
}
