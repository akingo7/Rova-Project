# Task 2 - Containerisation & CI/CD Pipeline

I built this lightweight Go REST API and automated GitHub Actions pipeline to demonstrate a production-ready container workflow covering unit testing, multi-stage builds, vulnerability scanning, and parallel registry deployments.

---

## Tool Choices & Rationale

### Why Go for the Application?
I wrote this service in **Go** using only the standard library (`net/http` and `encoding/json`). I chose Go over Python or Node.js for straightforward operational reasons:

* Go compiles to a standalone binary with zero external runtime dependencies (`CGO_ENABLED=0`).
* The final runtime image uses `alpine:3.24` and contains only the compiled binary and a non-root user. The entire image weighs roughly **15MB** (compared to 150MB+ for typical Python or Node images).
* Because there is no package manager, compiler, or interpreter in the final image, container security scanners like **Trivy** pass cleanly without high or critical CVEs.
* Go has a built-in test runner and HTTP testing package (`net/http/httptest`), so we don't need extra testing dependencies like `jest` or `pytest`.

---

## How the Container & Pipeline Work

### 1. Multi-Stage Dockerfile
The build is split into two distinct stages in the [`Dockerfile`](Dockerfile):

```text
 ┌────────────────────────────────────────────────────────┐
 │ Stage 1: Builder (golang:1.26-alpine)                  │
 │ - Copies app/go.mod and app/*.go                       │
 │ - Runs: CGO_ENABLED=0 go build -ldflags="-s -w"        │
 │ - Produces a stripped, static binary: /app/rova-api    │
 └──────────────────────────┬─────────────────────────────┘
                            │ (Only the compiled binary is copied)
                            ▼
 ┌────────────────────────────────────────────────────────┐
 │ Stage 2: Runtime (alpine:3.24)                         │
 │ - Creates dedicated non-root user: appuser (UID 10001) │
 │ - Copies /app/rova-api from builder                    │
 │ - Drops root permissions: USER 10001:10001             │
 │ - Exposes port 8080 and sets ENTRYPOINT                │
 └────────────────────────────────────────────────────────┘
```

### 2. CI/CD Pipeline Flow (GitHub Actions)
The workflow in [`.github/workflows/pipeline.yml`](../.github/workflows/pipeline.yml) triggers on pushes and pull requests to `main`, running through automated quality gates:

```text
 Push to 'main'
       │
       ▼
 1. Run Tests ───────────> Runs 'go test -v ./...' in task-2-cicd/app
       │                   (If tests fail, the workflow stops immediately)
       ▼
 2. Build Docker Image ──> Builds multi-stage image tagged with git SHA and latest
       │                   (Saves both tags into a single tar file artifact)
       ▼
 3. Security Scan ───────> Trivy scans the image for vulnerabilities
       │                   (Fails the pipeline on any HIGH or CRITICAL CVEs)
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

## Setup & How to Run

### Prerequisites
* **Docker** installed and running.
* **Go `>= 1.22`** (only to run unit tests and format locally without Docker).
* **curl** to test the endpoints.

---

### 1. Running Unit Tests Locally
```bash
cd app
go test -v ./...
cd ..
```

Expected output:
```text
=== RUN   TestHealthEndpoint
--- PASS: TestHealthEndpoint (0.00s)
=== RUN   TestRootEndpoint
--- PASS: TestRootEndpoint (0.00s)
=== RUN   TestNotFound
--- PASS: TestNotFound (0.00s)
PASS
ok  	rova-api	0.491s
```

---

### 2. Building the Docker Image
From the `task-2-cicd` directory:

```bash
docker build -t rova-api:latest .
```

To verify the image size and non-root user:
```bash
# Check image size (~15MB)
docker images rova-api:latest

# Confirm the container runs as UID 10001 (not root)
docker run --rm rova-api:latest id
# Output: uid=10001(appuser) gid=10001(appgroup)
```

---

### 3. Running the Container Locally
```bash
docker run -d -p 8080:8080 --name rova-api rova-api:latest
```

Test the endpoints:
```bash
# Root endpoint
curl http://localhost:8080/
# Output: {"message":"Welcome to Rova API","service":"rova-api","status":"running"}

# Health check endpoint
curl http://localhost:8080/health
# Output: {"service":"rova-api","status":"healthy"}
```

To stop and remove the container:
```bash
docker stop rova-api && docker rm rova-api
```

---

## Design Decisions & Trade-Offs

* **Go standard library over third-party frameworks:**
  * For an internal microservice or assessment task, `net/http` is fast, reliable, and introduces zero third-party dependencies that could lead to vulnerabilities.
* **Stripping debug symbols (`-ldflags="-s -w"`):**
  * Stripping debug symbols drops roughly 30% of the binary size without changing how the code runs in production.
* **Explicit non-root user (`UID 10001`):**
  * Rather than running as root or using an unnumbered username, I assigned UID/GID `10001`. This satisfies standard container security policies (e.g. Kubernetes `runAsNonRoot: true`).
* **Single tar file artifact in CI:**
  * Instead of building and uploading multiple separate image files between workflow jobs, the pipeline saves both `:latest` and `:${{ github.sha }}` into a single `rova-app.tar`. This cuts artifact transfer time and GitHub runner storage usage in half.
* **Parallel deployment targets:**
  * Running ECR and GitHub Container Registry (GHCR) pushes in parallel gives us multi-registry redundancy without doubling the pipeline run time.

---

## Staging to Production Promotion Strategy

In real-world operations, the deployment should never be done directly from a branch push to production without automated verification. Here is how I structure promotion in production:

### 1. Immutable Tagging (Never Deploy `:latest` to Production)
* Every build produces an image tagged with the **Git commit SHA** (e.g. `rova-api:sha-c4dbcd5`) and, on releases, a **Semantic Version** tag (e.g. `rova-api:v1.2.0`).
* We promote the same container image verified in Staging to Production. Rebuilding images between environments risks introducing unexpected dependency changes.

### 2. Environment Promotion Stages
1. **Automated Staging Rollout:**
   * Merging a PR into `main` builds the image, passes security scans, and pushes to ECR/GHCR.
   * A GitOps tool (like ArgoCD or Flux) or deployment webhook automatically deploys that new image SHA to the **Staging** cluster.
   * Automated integration and smoke tests run against Staging like the script in Task 3.
1. **Production Approval Gate:**
   * Production promotion is gated using **GitHub Actions Environments** requiring manual sign-off from designated team leads (SRE or Engineering Lead).
   * Once approved, the pipeline updates the production deployment manifests with the verified commit SHA.
   * Another method that can be used as the approval gate is using a multi-branch strategy. In this case, the production deployment will be done from a protected branch requiring only a pull request with the right number of approvals (e.g., 2) to make changes.
1. **Canary Rollout & Quick Rollback:**
   * Production rollouts use a **Canary** or **Rolling Update** strategy (e.g., routing 10% of user traffic to the new version before rolling it out to 100%).
   * If error rates or latency metrics spike on Datadog or CloudWatch, the orchestrator rolls back to the previous stable image tag immediately.

---

## Assumptions

* The container listens on port `8080`, configurable via the `PORT` environment variable.
* AWS credentials for pushing to ECR are stored in GitHub Repository Secrets (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, and `ECR_REPOSITORY`).
* GitHub Container Registry pushes use the built-in `${{ secrets.GITHUB_TOKEN }}` with `packages: write` permissions.
