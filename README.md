# AWS Multi-AZ Application Infrastructure with Terraform

Production-style AWS infrastructure built with **Terraform**, designed around **Multi-AZ networking, private application workloads, load balancing, Auto Scaling, RDS MySQL, host-level security, and remote Terraform state management**.

> **Project status:** The core Multi-AZ application and database infrastructure is implemented in Terraform. The S3 frontend, CloudFront, Route 53, ACM, and WAF layers are planned as the next phase.

## Architecture

```text
                              Internet
                                  |
                                  v
                     +------------------------+
                     | Application Load       |
                     | Balancer (Public)      |
                     +-----------+------------+
                                 |
                       HTTP :80  |
                                 v
                    +--------------------------+
                    | Target Group             |
                    +------------+-------------+
                                 |
                                 v
                    +--------------------------+
                    | Auto Scaling Group       |
                    | Desired: 2 | Max: 4      |
                    +------------+-------------+
                                 |
                 +---------------+---------------+
                 |                               |
                 v                               v
        ap-south-1b                       ap-south-1c
        Private App Subnet                Private App Subnet
        10.0.3.0/24                       10.0.4.0/24
                 |                               |
                 +---------------+---------------+
                                 |
                            NAT Gateway
                                 |
                         Internet Gateway

                    Database Tier - Private

                 +---------------+---------------+
                 |                               |
                 v                               v
        ap-south-1b                       ap-south-1c
        Private DB Subnet                 Private DB Subnet
        10.0.5.0/24                       10.0.6.0/24
                 |                               |
                 +---------------+---------------+
                                 |
                                 v
                         RDS MySQL Multi-AZ
                         db.t3.micro / 20 GB

Planned frontend layer:

User -> Route 53 -> CloudFront -> S3

Planned security/HTTPS layer:

CloudFront / ALB -> ACM -> HTTPS
CloudFront -> WAF
```

## Project Overview

This project demonstrates how to design AWS infrastructure using **Infrastructure as Code (IaC)** with Terraform.

The infrastructure separates the public load-balancing layer from private application workloads and places the database in dedicated private subnets. The application tier is distributed across two Availability Zones, while the RDS database is configured for Multi-AZ high availability.

The project also includes host-level security using **CrowdSec**, automated firewall enforcement with **nftables**, and a reusable **Golden AMI** security baseline for EC2 instances.

## Current Infrastructure

| Layer | AWS Service | Configuration |
|---|---|---|
| Network | VPC | `10.0.0.0/16` |
| Availability | Availability Zones | `ap-south-1b`, `ap-south-1c` |
| Public Network | Subnets | 2 |
| Application Network | Private Subnets | 2 |
| Database Network | Private Subnets | 2 |
| Internet Access | Internet Gateway | 1 |
| Private Outbound Access | NAT Gateway | 1 |
| Load Balancing | Application Load Balancer | Internet-facing |
| Compute | EC2 | `t3.micro` |
| Scaling | Auto Scaling Group | Desired 2 / Min 2 / Max 4 |
| Database | Amazon RDS MySQL | MySQL 8.0, `db.t3.micro`, 20 GB gp3 |
| Database HA | RDS Multi-AZ | Enabled |
| Database Access | Security Group | MySQL `3306` from application SG only |
| Secrets | RDS-managed password | AWS Secrets Manager integration |
| Monitoring | CloudWatch Agent | EC2 IAM role/profile |
| IaC | Terraform | AWS provider |
| State | Amazon S3 | Remote backend with versioning |

## Network Design

### VPC

- CIDR: `10.0.0.0/16`
- Region: `ap-south-1`
- DNS support enabled

### Public Subnets

| Subnet | CIDR | Availability Zone | Purpose |
|---|---|---|---|
| `public-1` | `10.0.1.0/24` | `ap-south-1b` | Public ALB / NAT |
| `public-2` | `10.0.2.0/24` | `ap-south-1c` | Public ALB |

Public subnets use the Internet Gateway for internet connectivity.

### Private Application Subnets

| Subnet | CIDR | Availability Zone | Purpose |
|---|---|---|---|
| `private-1` | `10.0.3.0/24` | `ap-south-1b` | EC2 application workloads |
| `private-2` | `10.0.4.0/24` | `ap-south-1c` | EC2 application workloads |

The application private route table provides outbound internet access through the NAT Gateway:

```text
Private EC2 -> NAT Gateway -> Internet Gateway -> Internet
```

There is no direct inbound internet route to the application instances.

### Private Database Subnets

| Subnet | CIDR | Availability Zone | Purpose |
|---|---|---|---|
| `private-3` | `10.0.5.0/24` | `ap-south-1b` | RDS subnet group |
| `private-4` | `10.0.6.0/24` | `ap-south-1c` | RDS subnet group |

The database subnets use a separate route table without a default internet route.

This keeps the database tier isolated from direct internet connectivity.

## Security Design

Traffic is restricted using separate security groups:

```text
Internet
   |
   | HTTP :80
   v
ALB Security Group
   |
   | HTTP :80
   v
Application Security Group
   |
   | MySQL :3306
   v
Database Security Group
```

### Security Group Rules

- **ALB SG:** HTTP `80` from the internet.
- **Application SG:** HTTP `80` only from the ALB security group.
- **Database SG:** MySQL `3306` only from the application security group.
- **EC2 instances:** Deployed in private subnets without public IP assignment.
- **RDS:** `publicly_accessible = false`.

This creates a controlled traffic path:

```text
Internet -> ALB -> EC2 -> RDS
```

## Amazon RDS MySQL

The database tier was added as a dedicated private database layer.

Configuration:

```hcl
resource "aws_db_instance" "database" {
  identifier         = "project"
  engine             = "mysql"
  engine_version     = "8.0"
  instance_class     = "db.t3.micro"
  allocated_storage  = 20
  storage_type       = "gp3"
  multi_az           = true

  db_subnet_group_name = aws_db_subnet_group.mysql.name

  vpc_security_group_ids = [
    aws_security_group.db_sg.id
  ]

  manage_master_user_password = true
  publicly_accessible         = false
  skip_final_snapshot         = true
}
```

The RDS subnet group uses the two dedicated database subnets in `ap-south-1b` and `ap-south-1c`.

`manage_master_user_password = true` allows Amazon RDS to manage the master password rather than storing a database password in Terraform configuration.

`multi_az = true` enables the RDS Multi-AZ deployment for high availability across Availability Zones.

> **Important:** The Terraform configuration and plan have been validated. The repository should not claim the RDS instance is deployed until `terraform apply` has successfully completed.

## Compute & Auto Scaling

The application tier uses an EC2 Launch Template and Auto Scaling Group.

```text
Minimum:  2
Desired:  2
Maximum:  4
```

The Auto Scaling Group spans the two private application subnets so workloads can run across both Availability Zones.

### Self-Healing Test

The intended validation flow is:

1. Start with the desired EC2 capacity.
2. Terminate an EC2 instance managed by the ASG.
3. ASG detects the capacity reduction.
4. ASG launches a replacement instance.
5. The replacement registers with the target group.
6. ALB health checks verify the replacement instance.

## Application Load Balancer

The ALB is internet-facing and deployed across the public subnets.

Current listener:

```text
Protocol: HTTP
Port: 80
```

Target group:

```text
Protocol: HTTP
Port: 80
Health Check Path: /
```

The ALB forwards requests to healthy EC2 instances in the private application subnets.

## Host-Level Security with CrowdSec

CrowdSec provides host-level intrusion detection and automated response for EC2 instances.

```text
SSH authentication failures
          |
          v
       CrowdSec
          |
   SSH brute-force scenario
          |
     Ban decision
          |
          v
 Firewall Bouncer
          |
          v
       nftables
          |
          v
   Malicious IP blocked
```

The security baseline includes:

- CrowdSec Security Engine
- SSH collection
- `crowdsecurity/ssh-bf` scenario
- CrowdSec Firewall Bouncer
- nftables enforcement
- Automated IP ban decisions

## Golden AMI

A hardened EC2 instance is used as the source for a reusable Golden AMI containing the security baseline.

```text
Hardened EC2
     |
     | CrowdSec + Firewall Bouncer
     v
  Golden AMI
     |
     v
Launch Template
     |
     v
Auto Scaling Group
```

This allows replacement instances launched by the Auto Scaling Group to inherit the configured security baseline instead of requiring manual security installation each time.

## IAM & CloudWatch

The project uses an EC2 IAM role and instance profile for CloudWatch Agent integration.

The AWS managed policy:

```text
CloudWatchAgentServerPolicy
```

is attached to the EC2 role so the instances can interact with CloudWatch without embedding AWS credentials on the servers.

## Terraform Remote State

Terraform state is stored remotely in Amazon S3.

```hcl
terraform {
  backend "s3" {
    bucket = "srinil-539"
    key    = "terraform.state"
    region = "ap-south-1"
  }
}
```

Configuration:

- Backend: S3
- Bucket: `srinil-539`
- Region: `ap-south-1`
- State key: `terraform.state`
- Bucket versioning: enabled

The backend was configured after the initial local-state setup and the existing Terraform state was migrated using `terraform init -migrate-state`.

## Terraform Validation

The configuration has been validated with:

```bash
terraform fmt
terraform validate
terraform plan
```

The latest plan reports:

```text
Plan: 32 to add, 0 to change, 0 to destroy.
```

The plan includes the Multi-AZ RDS database, dedicated database subnets, database route table, security groups, ALB, Auto Scaling infrastructure, IAM resources, and supporting network resources.

## CI/CD with GitHub Actions

GitHub Actions is used to validate Terraform changes and generate an infrastructure plan.

```text
Git Push / Pull Request
          |
          v
     GitHub Actions
          |
          +--> Checkout
          |
          +--> Setup Terraform
          |
          +--> Configure AWS credentials
          |
          +--> Verify AWS identity
          |
          +--> terraform init
          |
          +--> terraform fmt -check
          |
          +--> terraform validate
          |
          +--> terraform plan
```

The pipeline does not automatically run `terraform apply`, keeping infrastructure deployment under explicit control.

> **Security note:** The current workflow uses encrypted GitHub repository secrets for AWS credentials. For production workloads, GitHub Actions OIDC with short-lived IAM role credentials is preferred over long-lived access keys.

## Project Structure

```text
.
├── alb.tf
├── asg.tf
├── backend.tf
├── db.tf
├── iam.tf
├── launch_template.tf
├── output.tf
├── security.tf
├── variable.tf
├── vpc.tf
├── architecture.svg
├── screenshots/
├── .github/
│   └── workflows/
├── .gitignore
└── .terraform.lock.hcl
```

## Deployment

### Initialize Terraform

```bash
terraform init
```

### Format

```bash
terraform fmt
```

### Validate

```bash
terraform validate
```

### Review the Plan

```bash
terraform plan
```

### Deploy

```bash
terraform apply
```

### Destroy

```bash
terraform destroy
```

## Planned Next Phase

The infrastructure will be extended into a complete frontend + backend AWS architecture.

### Frontend

```text
Route 53
    |
    v
CloudFront
    |
    v
S3
```

Planned components:

- S3 frontend bucket
- Static website assets
- CloudFront distribution
- Origin Access Control (OAC)
- Route 53 DNS
- ACM certificate / HTTPS

### Backend

```text
Route 53
    |
    v
ALB
    |
    v
EC2 Auto Scaling
    |
    v
RDS MySQL Multi-AZ
```

### Security & Operations

- AWS WAF
- HTTPS listeners
- CloudWatch monitoring
- Additional logging and alerting
- Cost optimization review

## Technologies

**AWS · Terraform · VPC · EC2 · ALB · Auto Scaling · RDS MySQL · S3 · IAM · CloudWatch · Linux · Git · GitHub Actions · CrowdSec · nftables · Golden AMI**

## Author

**Srinil Reddy**

GitHub: `https://github.com/SRINILREDDY`
