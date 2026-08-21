# AWS 2-Tier Architecture with Terraform

Production-style AWS 2-tier web application infrastructure provisioned using Terraform.

## Architecture

```text
                         Internet
                            |
                            v
                Application Load Balancer
                  ┌─────────┴─────────┐
                  │                   │
            Public Subnet         Public Subnet
              AZ 1b                  AZ 1c
                  │                   │
                  └─────────┬─────────┘
                            |
                       Target Group
                            |
                 ┌──────────┴──────────┐
                 │                     │
            EC2 Instance          EC2 Instance
           Private Subnet         Private Subnet
              AZ 1b                  AZ 1c
                 │                     │
                 └──────────┬──────────┘
                            |
                       NAT Gateway
                            |
                     Internet Gateway
````

## Project Overview

This project demonstrates the design and deployment of a highly available 2-tier AWS architecture using Infrastructure as Code with Terraform.

The architecture separates the public load-balancing layer from the private application layer and uses Auto Scaling for application-instance self-healing.

## Key Features

* Custom VPC with `10.0.0.0/16` CIDR
* 2 public subnets across 2 Availability Zones
* 2 private subnets across 2 Availability Zones
* Internet Gateway for public subnet connectivity
* NAT Gateway for private subnet outbound connectivity
* Internet-facing Application Load Balancer
* Target Group with HTTP health checks
* EC2 Launch Template
* Auto Scaling Group with automatic instance replacement
* Security-group-based network isolation
* Apache HTTP server automated through EC2 user data
* Terraform variables and outputs
* Remote state management via a versioned S3 backend
* Git/GitHub version control

## Infrastructure Metrics

| Component            | Configuration |
| -------------------- | ------------- |
| AWS Region           | `ap-south-1`  |
| Availability Zones   | 2             |
| VPC                  | `10.0.0.0/16` |
| Public Subnets       | 2             |
| Private Subnets      | 2             |
| EC2 Instance Type    | `t3.micro`    |
| ASG Desired Capacity | 2             |
| ASG Minimum          | 2             |
| ASG Maximum          | 4             |
| ALB Listener         | HTTP :80      |
| Application Port     | 80            |
| NAT Gateway          | 1             |
| Internet Gateway     | 1             |

## Network Design

### Public Layer

The public subnets contain the Application Load Balancer.

```text
0.0.0.0/0 → Internet Gateway
```

Public subnets:

* `10.0.1.0/24` — `ap-south-1b`
* `10.0.2.0/24` — `ap-south-1c`

Public IP assignment is enabled for resources launched in these subnets.

### Private Application Layer

EC2 application instances run in private subnets.

```text
0.0.0.0/0 → NAT Gateway
```

Private subnets:

* `10.0.3.0/24` — `ap-south-1b`
* `10.0.4.0/24` — `ap-south-1c`

Public IP assignment is disabled.

## Security Design

Traffic is controlled using separate security groups:

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

### Security Controls

* ALB allows HTTP traffic from the internet.
* Application instances allow HTTP traffic only from the ALB security group.
* Database security group allows MySQL traffic only from the application security group.
* Application instances are deployed in private subnets.
* No direct internet ingress is allowed to the application instances.

> Note: The database security group is configured as part of the network/security design; an RDS database is not provisioned in this version of the project.

## Auto Scaling & Self-Healing

The Auto Scaling Group is configured with:

```text
Desired: 2
Minimum: 2
Maximum: 4
```

### Tested Scenario

1. Started with 2 EC2 instances.
2. Terminated an EC2 instance managed by the ASG.
3. ASG detected the capacity reduction.
4. A replacement EC2 instance was automatically launched.
5. The replacement instance registered with the target group.
6. ALB health checks validated the instance.

**Result:** Auto Scaling successfully restored the desired capacity.

## Load Balancer Testing

The application was accessed through the ALB DNS endpoint.

Target group configuration:

```text
Protocol: HTTP
Port: 80
Health Check Path: /
```

The ALB distributed traffic to healthy EC2 instances in the private subnets.

## Terraform Validation

The configuration was formatted and validated using:

```bash
terraform fmt
terraform validate
terraform plan
```

Validation completed successfully.

The final plan showed:

```text
Plan: 22 to add, 0 to change, 0 to destroy
```

The plan also generated outputs for:

* ALB DNS name
* VPC ID
* Public subnet IDs
* Private subnet IDs

## Remote State Management

Terraform state is stored remotely in a dedicated, versioned S3 bucket instead of locally, so state is durable, shareable, and protected against accidental loss or overwrite.

* **Backend:** S3
* **Bucket:** `srinil-539`
* **Region:** `ap-south-1`
* **State file key:** `terraform.state`
* **Bucket versioning:** Enabled

```hcl
terraform {
  backend "s3" {
    bucket = "srinil-539"
    key    = "terraform.state"
    region = "ap-south-1"
  }
}
```

The infrastructure was originally applied with local state. The backend was then reconfigured and the existing state migrated into S3 using `terraform init -migrate-state`, demonstrating backend reconfiguration on a live project rather than only a from-scratch remote setup.

## Project Structure

```text
.
├── alb.tf
├── asg.tf
├── backend.tf
├── launch_template.tf
├── output.tf
├── security.tf
├── variable.tf
├── vpc.tf
├── .gitignore
└── .terraform.lock.hcl
```

## Terraform Variables

The project uses variables for:

* VPC CIDR
* EC2 instance type

## Terraform Outputs

The project exposes:

* ALB DNS name
* VPC ID
* Public subnet IDs
* Private subnet IDs

## Deployment

### Initialize

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

### Review

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
## Technologies

**AWS · Terraform · Linux · Git · GitHub**

## Author

**Srinil Reddy**
