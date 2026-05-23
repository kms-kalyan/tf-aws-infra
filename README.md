# tf-aws-infra

> Production-style AWS reference architecture, defined end-to-end in Terraform — VPC networking, autoscaling Spring Boot service behind an ALB, RDS Postgres, KMS encryption, Lambda for email verification, and CI on every PR.

This is the infrastructure side of my AWS cloud computing project. The companion service it deploys lives at [**webapp**](https://github.com/kms-kalyan/webapp) (Spring Boot, packaged into a custom AMI via Packer). The Lambda function it provisions lives at [**serverless**](https://github.com/kms-kalyan/serverless).

The whole stack runs at `demo.madhusai.me` with TLS terminated at the load balancer.

## Architecture

                      ┌──────────────────┐
                      │  Route 53 (DNS)  │
                      └────────┬─────────┘
                               │
                               ▼
                      ┌──────────────────┐
                      │   ACM (TLS cert) │
                      └────────┬─────────┘
                               │
              Internet ───────►▼
                      ┌──────────────────────────┐
                      │ Application Load Balancer│
                      │  (public subnets, HTTPS) │
                      └────────┬─────────────────┘
                               │
                      ┌────────▼─────────┐
                      │ EC2 Auto Scaling │
                      │      Group       │  ← custom AMI built by Packer
                      │ (private subnet) │     in the webapp repo
                      └────┬────────┬────┘
                           │        │
                           ▼        ▼
                   ┌────────────┐ ┌────────────┐
                   │ RDS (Postgres)│ │   S3      │
                   │  (private)    │ │ (KMS-     │
                   │  KMS-encrypted│ │ encrypted)│
                   └───────────────┘ └───────────┘

> 📐 *Replacing this ASCII with a proper draw.io diagram is on the to-do list.*

## What's provisioned

| File | Resource |
|---|---|
| `vpc.tf` | VPC with custom CIDR |
| `subnet.tf` | Public + private subnets across multiple AZs |
| `internetGateway.tf` | Internet Gateway for public subnets |
| `routeTables.tf` | Route tables wiring subnets to the IGW |
| `app_load_balancer.tf` | Application Load Balancer + target group + Auto Scaling Group |
| `load_balancer_security.tf` | ALB security group (public HTTPS in) |
| `ec2_security.tf` | EC2 security group (traffic only from the ALB) |
| `rds_instance.tf` | RDS Postgres in private subnets |
| `rds_parameter_group.tf` | Custom RDS parameter group |
| `s3_bucket.tf` | S3 bucket for app file storage, KMS-encrypted |
| `encryption_keys.tf` | KMS keys for RDS, S3, and EBS volumes |
| `aws_lambda.tf` | Lambda for email verification (triggered by SNS on user signup) |
| `providers.tf` / `versions.tf` | Provider config + version pinning |
| `variables.tf` | Tunable inputs (CIDR, AMI ID, instance types, etc.) |

The EC2 Auto Scaling Group uses a custom AMI built by [Packer in the webapp repo](https://github.com/kms-kalyan/webapp). When webapp ships a new build, a fresh AMI ID flows into this Terraform stack as a variable.

## CI

`.github/workflows/terraform-ci.yml` runs on every pull request:

- `terraform fmt -check` — formatting
- `terraform validate` — syntax + provider checks
- `terraform plan` — surfaces the diff before merge

The main branch is protected; PRs cannot merge unless all three pass. This catches typos, missing variables, and accidental destructive changes before they hit `apply`.

## The hard parts

A few things took real time to get right:

**IAM permissions.** The single biggest time sink. The EC2 instance role needs to read from S3, decrypt with the right KMS key, publish to SNS, and pull secrets — each of those is a separate policy attachment with its own resource-scoping decisions. Too broad and you fail least-privilege; too narrow and the app silently 403s in production. Most of my early `terraform apply` failures weren't Terraform problems — they were "the role exists but can't decrypt this specific key" problems.

**Auto Scaling Group + ALB wiring.** Getting the ASG, the launch template, the target group, and the health check thresholds to all agree took several iterations. The first version would scale up fine but new instances would never register healthy with the target group because the security group didn't allow the ALB's health-check traffic. The second version registered but flapped because the health check path returned 200 before the app was actually ready. Eventually settled on a longer warm-up period and a proper `/healthz` endpoint in webapp.

**Security group chains.** Three security groups (ALB, EC2, RDS), each referencing the previous one's group ID rather than CIDR blocks. Conceptually clean but easy to get wrong — early attempts had the RDS group open to a CIDR that included the public subnet, which would have been a real problem in production.

## Manual steps (not in this repo)

To be honest about scope: DNS records in Route 53 and a few smaller pieces were configured directly in the AWS console rather than in Terraform. The TLS certificate is imported into ACM via:

```bash
aws acm import-certificate \
  --certificate fileb://path/to/demo.madhusai.me.crt \
  --private-key fileb://path/to/demo.madhusai.me.key \
  --certificate-chain fileb://path/to/demo.madhusai.me.ca-bundle
```

Moving these into Terraform is on the roadmap.

## Stack

Terraform 1.x · AWS provider · HCL · GitHub Actions

## Local usage

```bash
git clone https://github.com/kms-kalyan/tf-aws-infra.git
cd tf-aws-infra

# Configure AWS credentials via env vars or ~/.aws/credentials
terraform init
terraform plan
terraform apply
```

## Related repos

- **[webapp](https://github.com/kms-kalyan/webapp)** — the Spring Boot service this stack deploys, with the Packer config that produces the AMI
- **[serverless](https://github.com/kms-kalyan/serverless)** — the Lambda function code provisioned by `aws_lambda.tf`
