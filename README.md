# Rova Cloud & Infrastructure Assessment

This repository contains my submission for the Rova Cloud & Infrastructure assessment, structured into three practical tasks:

* **[`task-1-iac/`](task-1-iac/README.md):** Production AWS infrastructure provisioned with Terraform.
* **[`task-2-cicd/`](task-2-cicd/README.md):** Lightweight Go REST API, multi-stage Dockerfile, and GitHub Actions CI/CD pipeline with parallel ECR and GHCR deployments.
* **[`task-3-scripting/`](task-3-scripting/README.md):** Operational Bash health-check script with YAML configuration, retry backoff, and JSON output.

---

## Tool Choices & Rationale

### Task 1: Terraform on AWS
I used Terraform with the AWS Provider (v6.x) to manage the cloud infrastructure declaratively. Rather than using third-party registry modules that hide network details, I wrote direct AWS resources (`aws_vpc`, `aws_subnet`, `aws_lb`, `aws_autoscaling_group`) so route tables, subnet associations, and security boundaries are completely clear for review. 

For state management, I used an S3 backend with native state locking (`use_lockfile = true`), which eliminates the need for an extra DynamoDB table and cuts cloud costs.

### Task 2: Go, Docker & GitHub Actions
I built the application in **Go** using just the standard library (`net/http` and `encoding/json`). Go is ideal for containerized microservices:
* **Stage 1 (Builder):** Uses `golang:1.26-alpine` to compile a standalone, statically linked Linux binary (`CGO_ENABLED=0`) with debug symbols stripped.
* **Stage 2 (Runtime):** Copies only the single binary into a minimal `alpine:3.24` image, running as a non-root user (`appuser` with UID `10001`).

The resulting container is around **15MB**, boots in milliseconds, and passes Trivy vulnerability scans cleanly because there is no package manager or runtime interpreter in the final image. The GitHub Actions workflow tests, builds, scans, and deploys the container in parallel to both **Amazon ECR** and the **GitHub Container Registry (GHCR)**.

### Task 3: Bash Health-Check Script
For operational scripting, I chose **Bash** with `curl`, `yq`, and `jq`. Bash requires no virtual environments or compilation, running immediately on any Linux bastion host, server cron job, or CI runner. It reads target URLs and retry policies from [`endpoints.yaml`](task-3-scripting/endpoints.yaml), measures round-trip response latency, automatically retries on errors with backoff delays, and outputs structured JSON.

---

## Architecture Overview

### 1. AWS Infrastructure (Task 1)
The infrastructure is deployed in `eu-central-1` (Frankfurt) across two Availability Zones for high availability:

![Rova Task 1 Architecture](task-1-iac/images/architecture.png)

* **VPC & Subnets:** A `10.0.0.0/16` network divided into 2 public subnets (`10.0.0.0/24`, `10.0.1.0/24`) and 2 private subnets (`10.0.2.0/24`, `10.0.3.0/24`).
* **Traffic Routing:** Inbound traffic hits an internet-facing Application Load Balancer in the public subnets. The ALB forwards requests on port 80 to EC2 instances running inside private subnets.
* **Security Boundaries:** EC2 instances have no public IPs and only accept HTTP traffic directly from the ALB security group. Outbound traffic (for OS packages) routes through a single NAT Gateway in Public Subnet A.
* **Auto Scaling:** An Auto Scaling Group (Min: 2, Desired: 2, Max: 4) spans both private subnets with a target tracking scaling policy that keeps average CPU utilization around 50%. Instances serve a branded landing page showing their dynamic instance ID and AZ via IMDSv2.

---

### 2. CI/CD Pipeline (Task 2)
The GitHub Actions workflow triggers on pushes and pull requests to `main` through four quality gates:

```text
 Push to 'main'
       │
       ▼
 1. Run Tests ───────────> Runs 'go test -v ./...' in task-2-cicd/app
       │
       ▼
 2. Build Docker Image ──> Builds multi-stage image tagged with git SHA and :latest
       │                   (Saves into a single tar file artifact)
       ▼
 3. Security Scan ───────> Trivy scans the container filesystem for vulnerabilities
       │                   (Blocks pipeline on any HIGH or CRITICAL issues)
       ▼
 ┌──────────────────────────────────────────────┐
 │ 4. Parallel Deployments (Push to main only)  │
 ├───────────────────────┬──────────────────────┤
 │ Deploy to AWS ECR     │ Deploy to GHCR       │
 │ (Authenticates &      │ (Pushes image to     │
 │  pushes to AWS ECR)   │  ghcr.io/akingo7)    │
 └───────────────────────┴──────────────────────┘
```

---

### 3. Health-Check Flow (Task 3)
[`healthcheck.sh`](task-3-scripting/healthcheck.sh) reads service definitions from [`endpoints.yaml`](task-3-scripting/endpoints.yaml), probes each URL using `curl`, captures the status code and latency in milliseconds, and retries on errors with backoff delays. It outputs a formatted JSON summary and returns exit code `0` if all pass or `1` if any endpoint remains down.

---

## Quickstart & How to Run

### Prerequisites
* **AWS CLI** configured (`aws configure` or `export AWS_PROFILE="<profile>"`).
* **Terraform CLI** (`>= 1.10.0`).
* **Docker** installed and running.
* **Go** (`>= 1.22`, only if running tests outside Docker).
* **Bash**, **`curl`**, **`yq`** (v4.x), and **`jq`** for the health-check script.

---

### Running Task 1 (Infrastructure)
See [`task-1-iac/README.md`](task-1-iac/README.md) for full documentation.

```bash
cd task-1-iac

# 1. Edit variables if needed
vim terraform.tfvars

# 2. Initialize and deploy
# (Use -backend=false if your S3 remote state bucket is not yet created)
terraform init -backend=false
terraform validate
terraform plan
terraform apply

# 3. View the ALB DNS name
terraform output resource_output
```

---

### Running Task 2 (Application & Container)
See [`task-2-cicd/README.md`](task-2-cicd/README.md) for full documentation.

```bash
cd task-2-cicd

# Run unit tests locally
cd app && go test -v ./... && cd ..

# Build and run the container
docker build -t rova-api:latest .
docker run -d -p 8080:8080 --name rova-api rova-api:latest

# Test endpoints
curl http://localhost:8080/
curl http://localhost:8080/health
```

---

### Running Task 3 (Health Check)
See [`task-3-scripting/README.md`](task-3-scripting/README.md) for full documentation.

```bash
cd task-3-scripting

# Make executable
chmod +x healthcheck.sh

# Run against default endpoints (includes Rova and FCMB endpoints)
./healthcheck.sh

# Or pass a custom configuration file
./healthcheck.sh custom-endpoints.yaml
```

---

## Design Decisions & Trade-Offs

* Direct resource declarations keep the network topology completely transparent and make it easy to see how route tables, subnets, and security groups link together.
* I deployed one NAT Gateway in Public Subnet A and routed both private subnets through it. In an enterprise system, run one NAT per AZ for full egress redundancy. For this assessment, a single NAT keeps running costs down (~$0.045/hr per NAT) while still giving private instances outbound internet access.
* Target tracking automatically adjusts capacity to maintain 50% CPU utilization, handling the CloudWatch alarms and scaling math without rigid manual thresholds.
* Compiling a static Go binary lets us run on a bare `alpine:3.24` image at ~15MB with a non-root user (`UID 10001`). This eliminates interpreters and package managers, allowing Trivy scans to pass without high or critical CVE warnings.
* For jump-box scripts and cron jobs, Bash with standard tools (`curl`, `jq`, `yq`) avoids packaging overhead, virtualenvs, or pip installs.

---

## Assumptions

* **AWS Region:** Deployed to `eu-central-1` (Frankfurt).
* **Port 80 HTTP:** Used on the ALB so the reviewer can test the endpoint immediately without setting up a custom domain name or SSL certificate.
* **Instance Sizing:** Uses free-tier eligible `t3.micro` instances.
* **CI/CD Secrets:** AWS credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `ECR_REPOSITORY`) are saved in GitHub Repository Secrets.

---

## Teardown & Cleanup

To destroy all AWS infrastructure provisioned in Task 1:

```bash
cd task-1-iac
terraform destroy -auto-approve
```
