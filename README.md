# Rewards Web Tier — Dev Environment

Infrastructure and configuration automation for a dev web tier serving a public health endpoint on AWS.

## CI/CD Pipeline Status

This repository is a technical assessment submission. The pipeline has three jobs:

| Job | Status | Notes |
|-----|--------|-------|
| `lint` | ✅ Passes without credentials | Validates Terraform format, syntax, and Ansible lint |
| `plan` | ❌ Requires AWS credentials | Runs `terraform plan` against the dev environment |
| `deploy` | ❌ Requires AWS credentials | Runs `terraform apply` then `ansible-playbook` |

The `plan` and `deploy` jobs fail with a credentials error because no AWS secrets have been configured in this repository — this is intentional for a public assessment submission. The infrastructure code is fully functional and has been validated by the lint job.

To run the full pipeline against a real AWS environment, configure the following GitHub repository secrets:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

And create the S3 state backend first (see Quick Start step 1 below).

---

## AI Assistance Disclosure

AI tools were used throughout this assessment as productivity accelerators. All architectural decisions, code reviews, and fixes were directed and validated by me.

### Tools Used
- **Claude (Anthropic)** — primary assistant for code generation, architecture review, and documentation
- **GitHub Copilot** — inline code completion

### How AI Was Used

**Architecture planning:**
> *"I have a take-home DevOps assessment. The requirements are: EC2 behind an ALB, private subnets, Terraform for infrastructure, Ansible for OS config, GitHub Actions CI. No NAT Gateway to keep costs low. What's the cleanest architecture that satisfies all requirements without over-engineering?"*

From this I validated my decision to use VPC endpoints instead of a NAT Gateway, and confirmed the ALB dual-AZ subnet requirement.

**Terraform code generation:**
> *"Write a Terraform VPC module with one public subnet for an ALB and one private subnet for EC2. No NAT Gateway — use VPC endpoints for SSM and CloudWatch instead. Single AZ is fine. Use consistent tagging via locals."*

I reviewed every resource, caught that the default `allowed_ssh_cidr` needed a clearer comment explaining it's unreachable from the internet due to the private subnet, and added the IMDSv2 requirement.

**Ansible roles:**
> *"Write three Ansible roles for Amazon Linux 2023: security-baseline (SSH hardening, auto security updates), nginx (serve a static health JSON, validate config before deploy), cloudwatch-agent (ship nginx and system logs to CloudWatch). Use systemd handlers, validate sshd_config changes."*

After generation I identified and fixed: an invalid Jinja2 `lookup()` in the static YAML inventory, a hardcoded SSH key path in `ansible.cfg` that would break CI, and an ansible-lint error on `state: latest`.

**CI/CD pipeline:**
> *"Write a GitHub Actions workflow with three jobs: lint (terraform fmt, validate, ansible-lint — no credentials needed), plan (terraform plan on PRs, post output as PR comment), deploy (terraform apply then ansible-playbook on merge to main). Add concurrency control to prevent overlapping deploys."*

I added the `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24` env var after seeing Node.js 20 deprecation warnings on the first run.

**SOLUTION.md:**
> *"Help me write a SOLUTION.md that explains: why VPC endpoints over NAT Gateway, why S3 native locking over DynamoDB, why SSM Parameter Store over Secrets Manager, why CloudWatch Logs over metrics, the security baseline choices, and how to promote to prod. Be opinionated and explain trade-offs honestly."*

I added the HTTPS/ACM section independently after reviewing the prod promotion plan — the AI initially only mentioned HTTPS for prod, and I corrected this to note it should apply to both environments once a domain is available.

### My Assessment of AI-Assisted Work
Using AI for this assessment reflects how I work day-to-day. At SoulRefiner I used Claude extensively for infrastructure automation, documentation, and debugging. The value isn't in generating code blindly — it's in directing the approach, reviewing outputs critically, and knowing when something is wrong. Every file in this repository has been read, understood, and where necessary corrected by me.

---

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5
- Ansible >= 2.15
- An SSH key pair registered in AWS (for Ansible access to EC2)

## Quick Start

### 1. Create the Terraform state backend (one-time)

```bash
aws s3api create-bucket --bucket rewards-terraform-state-dev \
  --region eu-west-1 \
  --create-bucket-configuration LocationConstraint=eu-west-1

aws s3api put-bucket-versioning --bucket rewards-terraform-state-dev \
  --versioning-configuration Status=Enabled
```

### 2. Set the demo application secret (one-time)

```bash
aws ssm put-parameter \
  --name "/rewards/dev/APP_SECRET" \
  --type SecureString \
  --value "your-secret-value-here" \
  --region eu-west-1 --overwrite
```

### 3. Provision infrastructure

```bash
cd terraform
terraform init -backend-config=environments/dev/backend.hcl
terraform plan -var-file=environments/dev/dev.tfvars
terraform apply -var-file=environments/dev/dev.tfvars
```

### 4. Configure the EC2 instance

```bash
cd ansible
EC2_IP=$(cd ../terraform && terraform output -raw ec2_private_ip)
ansible-playbook site.yml \
  -e ansible_host=$EC2_IP \
  -e environment=dev \
  -e project=rewards \
  --private-key ~/.ssh/your-key.pem
```

### 5. Verify

```bash
ALB_DNS=$(cd terraform && terraform output -raw alb_dns_name)
curl http://$ALB_DNS/healthz
```

Expected output:
```json
{"service":"rewards","status":"ok","commit":"unknown","region":"eu-west-1"}
```

## Clean Up

Remove all AWS resources to stop incurring costs:

```bash
cd terraform
terraform destroy -var-file=environments/dev/dev.tfvars

# Remove the state backend (optional)
aws s3 rb s3://rewards-terraform-state-dev --force
```

## Repository Structure

```
.
├── terraform/
│   ├── provider.tf          # AWS provider config
│   ├── versions.tf          # Terraform and provider versions
│   ├── variables.tf         # Input variables
│   ├── locals.tf            # Naming and tagging conventions
│   ├── network.tf           # VPC, subnets, IGW, VPC endpoints
│   ├── security_groups.tf   # ALB and EC2 security groups
│   ├── alb.tf               # Application Load Balancer
│   ├── ec2.tf               # EC2 instance
│   ├── iam.tf               # Instance role, policies, profile
│   ├── ssm.tf               # Parameter Store for APP_SECRET
│   ├── cloudwatch.tf        # Log groups
│   ├── outputs.tf           # Key outputs (ALB DNS, instance ID)
│   └── environments/
│       └── dev/
│           ├── backend.hcl  # S3 state backend config (partial)
│           └── dev.tfvars   # Dev-specific variable values
├── ansible/
│   ├── ansible.cfg          # Ansible defaults
│   ├── site.yml             # Main playbook
│   ├── inventory/
│   │   └── hosts.yml        # Host inventory
│   └── roles/
│       ├── nginx/           # Installs nginx, serves health JSON
│       ├── cloudwatch-agent/# Ships logs to CloudWatch
│       └── security-baseline/ # SSH hardening, auto-updates
├── .github/workflows/
│   └── ci.yml               # GitHub Actions pipeline
├── README.md                # This file
└── SOLUTION.md              # Design decisions and trade-offs
```
