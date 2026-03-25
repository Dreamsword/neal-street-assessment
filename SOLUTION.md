# Solution — Design Decisions and Trade-offs

## Architecture Overview

```
Internet
   │
   ▼
┌───────────────────────────────────────────────────────────┐
│  VPC 10.0.0.0/16                                         │
│                                                          │
│  ┌──────────────────┐  ┌──────────────────┐              │
│  │ Public Subnet A  │  │ Public Subnet B  │              │
│  │ 10.0.1.0/24      │  │ 10.0.3.0/24      │              │
│  │ (eu-west-1a)     │  │ (eu-west-1b)     │              │
│  └────────┬─────────┘  └────────┬─────────┘              │
│           │    ALB spans both   │                        │
│           └────────┬────────────┘                        │
│                    │                                     │
│                    ▼                                     │
│  ┌─────────────────────────────┐                         │
│  │ Private Subnet              │                         │
│  │ 10.0.2.0/24 (eu-west-1a)   │                         │
│  │                             │                         │
│  │  ┌───────────┐             │                         │
│  │  │   EC2     │             │                         │
│  │  │ (nginx)   │             │                         │
│  │  └─────┬─────┘             │                         │
│  │        ▼                   │                         │
│  │  VPC Endpoints             │                         │
│  │  (SSM, CW Logs)           │                         │
│  └─────────────────────────────┘                         │
│         │                                                │
│    Internet GW                                           │
└───────────────────────────────────────────────────────────┘
```

## Key Decisions

### Network: No NAT Gateway

**Decision:** Use VPC endpoints instead of a NAT Gateway for the private subnet.

**Why:** A NAT Gateway costs ~$32/month just sitting there, plus data processing charges. For a dev environment with one EC2 instance that only needs to reach AWS services (SSM, CloudWatch), VPC endpoints are a better fit. The EC2 instance doesn't need general internet access — it's configured by Ansible over SSH and talks to AWS APIs through the endpoints.

**Trade-off:** If the instance needed to pull packages from the internet (yum updates, pip install), you'd either need a NAT Gateway or to pre-bake the AMI. For this exercise, Amazon Linux 2023 includes everything we need and the CloudWatch agent is available as a dnf package from Amazon's repos accessible via VPC endpoints.

**In production:** A NAT Gateway would probably be justified once you have multiple services that need outbound internet access. The cost becomes a rounding error relative to the workload.

### Load Balancer: ALB over CLB

**Decision:** Application Load Balancer, not Classic Load Balancer.

**Why:** CLB is deprecated. ALB supports path-based routing, HTTP/2, better health checks, and native access logging to S3. The cost difference is negligible (~$0.02/hour for ALB). When this scales to multiple services or paths, ALB handles it without changes.

**Note on AZs:** ALB requires subnets in at least two AZs, so I've included a second public subnet in eu-west-1b. The EC2 instance only runs in the primary AZ (single-AZ topology as the brief allows). For prod, you'd add private subnets in both AZs and run instances in each.

### State: S3 with Native Locking

**Decision:** Terraform remote state in S3 with native state locking (`use_lockfile = true`).

**Why this over alternatives:**
- **Local state:** No locking, no collaboration, state file can be lost. Only works for solo experimentation.
- **Terraform Cloud:** Better UI and built-in locking, but adds a vendor dependency and the free tier is limited. For a small team, it's worth considering but not necessary.
- **S3 + DynamoDB (legacy):** This used to be the standard pattern, but AWS added native S3 state locking via conditional writes in late 2023. DynamoDB is no longer needed.
- **S3 with native locking (current):** Free, native to AWS, versioning provides state history. This is the standard pattern for small-to-medium teams today.

**Trade-off:** The state bucket has to be created before Terraform can run (chicken-and-egg). I've included the bootstrap commands in the README. In a mature setup, you'd have a separate "bootstrap" Terraform config or a script that creates these.

### Secrets: SSM Parameter Store over Secrets Manager

**Decision:** Store `APP_SECRET` in SSM Parameter Store (SecureString), not Secrets Manager.

**Why:** SSM Parameter Store is free (Standard tier). Secrets Manager costs $0.40/secret/month + API call charges. For a demo secret and most application config, SSM is the right tool. Secrets Manager adds automatic rotation and cross-account sharing, which aren't needed here.

**Pattern:** The Terraform creates the parameter with a placeholder value and uses `lifecycle { ignore_changes = [value] }` so the real secret is set out-of-band (via CLI or console) and Terraform won't overwrite it on subsequent applies.

### Health Endpoint: Static nginx Response

**Decision:** Serve the health JSON as a static file from nginx, not a dynamic app.

**Why:** The brief says "you decide whether the health response is static or a minimal app." A static JSON file served by nginx is:
- Fastest possible response (~0.1ms)
- Zero dependencies beyond nginx
- Survives application crashes (if there were an app)
- Simplest to test and debug

The commit hash is injected by Ansible at deploy time via the template. In a real setup with a dynamic app, the `/healthz` endpoint would be served by the app itself and nginx would proxy to it.

### Observability: CloudWatch Logs (not metrics)

**Decision:** Centralized logs as the mandatory observability path.

**Why:** The brief says pick one — either logs or metrics/alarms. I went with logs because:
- CloudWatch Logs integrates natively with the CloudWatch agent
- The agent is installed and configured entirely by Ansible, no additional AWS resources needed beyond log groups
- Log data is more useful for debugging than basic CPU/memory metrics at this stage
- The ALB already provides request-level metrics for free (request count, latency, 5xx rate)

**What's collected:** nginx access logs, nginx error logs, and `/var/log/messages` (system). Each goes to its own log group with 7-day retention.

**Stretch goal:** Adding CloudWatch alarms on ALB metrics (UnHealthyHostCount > 0, 5xx rate > threshold) would take ~20 lines of Terraform and completes the "is it up?" monitoring.

### Security Baseline

The Ansible `security-baseline` role applies:
- **No root SSH:** `PermitRootLogin no`
- **Key-only auth:** `PasswordAuthentication no`
- **Session timeout:** `ClientAliveInterval 300` (5 min idle disconnect)
- **Auto security updates:** `dnf-automatic` with `upgrade_type = security`
- **IMDSv2 required:** Set in Terraform (`http_tokens = "required"`) to prevent SSRF credential theft
- **Encrypted root volume:** EBS encryption enabled by default

### CI/CD: GitHub Actions

**Pipeline structure:**
1. **Lint job** (every PR and push): `terraform fmt -check`, `terraform validate`, advisory `ansible-lint`
2. **Plan job** (PRs only): Runs `terraform plan` and posts the output as a PR comment so reviewers can see what will change
3. **Deploy job** (merge to main only): `terraform apply -auto-approve` then `ansible-playbook`

**Concurrency control:** `concurrency: { group: deploy-dev }` prevents overlapping deploys. If a deploy is running and another merge lands, the second queues instead of stomping on the first.

## Promotion to Production

To promote this to a production environment:

### 1. Create a prod tfvars file

```
terraform/environments/prod/
├── backend.hcl   # Points to a separate S3 bucket
└── prod.tfvars   # Different CIDR ranges, instance type, retention
```

Changes from dev:
- Multi-AZ (2+ subnets in different AZs)
- Larger instance type (t3.small or bigger)
- Longer log retention (30+ days)
- HTTPS on the ALB (ACM certificate) — see note below
- Auto Scaling Group instead of a single EC2 instance
- Separate AWS account (recommended) or at minimum separate IAM credentials
- SSH rule removed from EC2 security group; Ansible runs over SSM Session Manager instead

**Note on HTTPS:** ACM certificates are free and HTTPS should be enabled in **both dev and prod** as soon as a domain is available. Dev/prod parity here matters — HTTP-only dev can hide SSL termination bugs, mixed-content issues, and cookie security flag problems before they reach prod. The only prerequisite is a custom domain; ACM cannot issue certificates for ALB-generated DNS names (e.g. `*.elb.amazonaws.com`). The HTTP listener in this exercise is a bootstrap state only. Once a domain exists, the ALB listener switches to HTTPS (port 443) with an ACM certificate ARN, and an HTTP→HTTPS redirect rule handles port 80.

### 2. Separate credentials

GitHub environments already support this:
- `dev` environment has its own `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
- `prod` environment would have different credentials, ideally from a separate AWS account
- The prod environment would also have a **required reviewers** protection rule

### 3. Pipeline changes

Add a `deploy-prod` job that:
- Only runs on tagged releases or manual trigger
- Uses the `prod` environment (which requires approval)
- Runs `terraform plan` first, then `terraform apply` after manual approval

```yaml
deploy-prod:
  needs: deploy-dev
  if: github.ref_type == 'tag'
  environment:
    name: prod
    # GitHub will require manual approval before this runs
  steps:
    - ... # Same as deploy-dev but with prod vars
```

## Cost Awareness

### Dev environment monthly cost estimate

| Resource | Estimated Cost |
|----------|---------------|
| EC2 t2.micro (750h free tier) | $0.00 |
| ALB (~$0.02/hr + LCU) | ~$16/month |
| S3 state bucket | ~$0.01 |
| VPC endpoints (4x ~$0.01/hr) | ~$29/month |
| CloudWatch Logs (5GB free) | ~$0.00 |
| SSM Parameter Store (standard) | $0.00 |
| **Total** | **~$45/month** |

**Note:** The VPC endpoints are the biggest cost driver. In a real environment with multiple services sharing the VPC, this cost is amortised. For a pure cost-minimisation dev setup, you could use a public subnet with tight security groups instead — but that contradicts the "protected subnets" requirement.

### Clean up

```bash
terraform destroy -var-file=environments/dev/dev.tfvars
aws s3 rb s3://rewards-terraform-state-dev --force
```
