# Task 3 - Operational Health-Check Script

I built this operational health check to probe HTTP/HTTPS endpoints, track response latency, automatically retry failed requests with backoff, and return structured JSON results.

All target URLs, timeouts, and retry policies are defined in [`endpoints.yaml`](endpoints.yaml), and the logic is handled by a single shell script: [`healthcheck.sh`](healthcheck.sh).

---

## Tool Choices & Rationale

### Why Bash, curl, and yq?
I picked **Bash** along with **`curl`**, **`yq`**, and **`jq`** for practical operational reasons:

* **Zero setup overhead:** You don't need to spin up a Python virtualenv, install `pip` packages, or compile binaries. It runs immediately on standard Linux jump boxes, bastion servers, and CI/CD runners.
* **Standard Unix integration:** It sticks to Unix conventions and uses process exit codes (`0` for success, `1` if anything fails). That makes it easy to hook into a cron job, a Kubernetes container probe, or a GitHub Actions step.
* **YAML is friendly for ops teams:** Using [`endpoints.yaml`](endpoints.yaml) lets teammates add comments, organize URLs by service, and edit endpoints without breaking JSON commas.

---

## How the Script Works

```text
 endpoints.yaml ──> healthcheck.sh ──> curl (checks HTTP status & latency)
                          │
                          ├──> [PASS] Status matches expected -> log latency & move on
                          └──> [FAIL] Wait backoff time & retry up to max_retries
                                      │
                                      └──> Print summary, output JSON, and exit (0 or 1)
```

### Execution Steps
1. The script reads [`endpoints.yaml`](endpoints.yaml) for global defaults (`max_retries`, `backoff_seconds`, `timeout_seconds`) and pulls the list of target endpoints.
2. It tests each endpoint using `curl`, discards the response body (`-o /dev/null`), and captures the HTTP status code and latency in milliseconds.
3. If an endpoint returns an unexpected status code or times out, the script logs a retry notice, pauses for the configured backoff period, and tries again.
4. **Prints a JSON report:** After checking all endpoints, it prints a clean JSON summary containing per-endpoint metrics and overall system status.
5. **Standard Exit Codes:**
   * Exits **`0`** if all endpoints are healthy.
   * Exits **`1`** if any endpoint remains down after exhausting all retries.

---

## Quickstart & Usage

### Prerequisites
Make sure you have these CLI tools installed:
* **Bash**
* **`curl`**
* **`yq`** (v4.x)
* **`jq`**

#### Installation
* **macOS (Homebrew):**
  ```bash
  brew install yq jq curl
  ```
* **Debian / Ubuntu:**
  ```bash
  sudo apt-get update && sudo apt-get install -y jq curl
  sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
  sudo chmod +x /usr/local/bin/yq
  ```

---

### Running the Script

1. **Make it executable:**
   ```bash
   chmod +x healthcheck.sh
   ```

2. **Run against the default `endpoints.yaml`:**
   ```bash
   ./healthcheck.sh
   ```

3. **Run with a custom config file:**
   ```bash
   ./healthcheck.sh /path/to/my-endpoints.yaml
   ```

---

### Sample Output

Here is a real terminal run showing successful checks against Rova and FCMB endpoints, alongside an intentional failure to test the retry loop:

```output
$ ./healthcheck.sh

Checking 4 endpoints from endpoints.yaml...

  [PASS] Rova Digital Banking Platform -> HTTP 200 (430ms)

  [PASS] FCMB Corporate Portal -> HTTP 200 (543ms)

  [PASS] FCMB Business Gateway -> HTTP 200 (504ms)

  [RETRY 1/2] Simulated Down Service (Failure & Retry Test) -> HTTP 503 (expected 200, 1096ms)
  [RETRY 2/2] Simulated Down Service (Failure & Retry Test) -> HTTP 503 (expected 200, 1387ms)
  [FAIL] Simulated Down Service (Failure & Retry Test) is down after 2 attempts.

----------------------------------------
Summary: 3/4 passed (1 failed)
----------------------------------------
{
  "timestamp": "2026-09-29T23:00:00Z",
  "total": 4,
  "failed": 1,
  "results": [
    {
      "name": "Rova Digital Banking Platform",
      "url": "https://getrova.com",
      "status": "200",
      "latency_ms": 430,
      "result": "healthy"
    },
    {
      "name": "FCMB Corporate Portal",
      "url": "https://www.fcmb.com",
      "status": "200",
      "latency_ms": 543,
      "result": "healthy"
    },
    {
      "name": "FCMB Business Gateway",
      "url": "https://www.fcmb.com/business",
      "status": "200",
      "latency_ms": 504,
      "result": "healthy"
    },
    {
      "name": "Simulated Down Service (Failure & Retry Test)",
      "url": "https://httpbin.org/status/503",
      "status": "503",
      "latency_ms": 1387,
      "result": "unhealthy"
    }
  ]
}
```

---

## Design Decisions & Trade-Offs

* **Bash over Python/Go:**
  * Bash starts instantly and runs everywhere without managing dependencies. The obvious trade-off is performance: Bash checks endpoints sequentially. If we were checking 100+ endpoints concurrently, Go with goroutines would be a better choice.
* **Throwing away the response body (`-o /dev/null`):**
  * I use `curl -s -L -o /dev/null` to verify DNS resolution, TLS certificates, and HTTP response headers without wasting network bandwidth downloading the whole HTML or asset payloads.
* **Per-endpoint overrides:**
  * In [`endpoints.yaml`](endpoints.yaml), every endpoint can optionally specify its own `timeout_seconds`, `max_retries`, or `expected_status`. If omitted, it falls back to the top-level `settings`.

---

## Assumptions

* The server running the script has outbound internet access to target endpoints.
* An endpoint is considered healthy if its status code matches `expected_status` (defaults to `200`).
* Latency measures full round-trip client time (`time_total` in curl), which covers DNS resolution, TCP connection, TLS handshake, and time-to-first-byte.

---

## Production Recommendations & Limitations

### How I'd Run This in Production
1. **Scheduled Runs:**
   * Run the script every few minutes (30 mins) as a Kubernetes `CronJob` or a systemd timer on an observability box.
1. **Pushing Metrics:**
   * Feed the JSON output into an observability stack (e.g., Datadog, Prometheus, or AWS CloudWatch Logs) to create uptime dashboards and latency heatmaps.
1. **Alerting:**
   * Integrate the non-zero exit code (`exit 1`) into an alert bot (Slack webhook or PagerDuty) if the script fails two runs in a row.
1. **Multiple Regions:**
   * Run the check from multiple cloud regions and private VPC subnets to spot localized routing issues and internal service latency.

### Limitations
* **Sequential checks:** It checks one URL at a time. If an endpoint hangs and times out across multiple retries, it delays checks for the remaining endpoints.
* **Shallow health check:** It only confirms that the web server answers with the right HTTP code. It doesn't inspect the body to verify whether the downstream database or cache is healthy.
* **Single point of observation:** Running checks from one server only shows you what that specific host sees; it won't reveal localized CDN edge issues elsewhere.
