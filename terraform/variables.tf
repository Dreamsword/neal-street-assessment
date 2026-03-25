variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Project name used in resource naming and tags"
  type        = string
  default     = "rewards"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet (ALB)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet (EC2)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "Primary AZ for EC2 and subnets"
  type        = string
  default     = "eu-west-1a"
}

variable "availability_zone_secondary" {
  description = "Secondary AZ — ALB requires subnets in at least 2 AZs"
  type        = string
  default     = "eu-west-1b"
}

variable "public_subnet_cidr_secondary" {
  description = "CIDR for the secondary public subnet (ALB requirement)"
  type        = string
  default     = "10.0.3.0/24"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance (Amazon Linux 2023)"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "SSH key pair name for EC2 access (used by Ansible)"
  type        = string
  default     = ""
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH to the bastion/EC2 (for Ansible provisioning)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "owner" {
  description = "Owner tag value"
  type        = string
  default     = "candidate"
}

variable "cost_center" {
  description = "Cost center tag value"
  type        = string
  default     = "payments"
}
