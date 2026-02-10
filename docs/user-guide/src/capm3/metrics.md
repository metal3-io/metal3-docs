# Metrics

CAPM3 exposes Prometheus-compatible metrics that can be scraped for monitoring
and observability. This page explains how to configure and access these metrics.
The CAPM3 exposes metrics on port 8443 by default. These metrics provide
insights into the controller's operation, including reconciliation loops, API
requests, and resource states. To see the full list of available metrics, check
kubebuilder [reference](https://book.kubebuilder.io/reference/metrics-reference.html)

## Scraping Metrics

There are two main ways to scrape CAPM3 metrics:

1. **Quick Way (curl/test Pod)**: For quick local testing, debugging, or one-off
   metric checks without setting up a full monitoring stack
1. **Prometheus Integration**: For production environments requiring continuous
   monitoring, alerting, and long-term storage

## 1. Quick Way: Manual Scraping with curl/test Pod

Manual scraping is ideal for quick local testing, debugging, or one-off metric
checks without setting up a full monitoring stack.

### Configuration

If `--insecure-diagnostics` is set to true, CAPM3 serves metrics via http and
without authentication/authorization. For quick scraping with curl or test pod,
you need to turn on the insecure diagnostics flag in the CAPM3 deployment:

```bash
kubectl -n capm3-system get deployment capm3-controller-manager -o json | \
  jq '.spec.template.spec.containers[0].args |= (map(if startswith("--insecure-diagnostics") then "--insecure-diagnostics=true" else . end) + (if any(.[]; startswith("--insecure-diagnostics")) then [] else ["--insecure-diagnostics=true"] end))' | \
  kubectl apply -f -
```

Alternatively, edit the deployment directly to add `- --insecure-diagnostics=true`

```bash
kubectl -n capm3-system edit deployment capm3-controller-manager
```

### Scraping

1. Get the CAPM3 controller manager pod name and forward the metrics port:

   ```bash
   CAPM3_POD=$(kubectl -n capm3-system get pods -l control-plane=controller-manager -o jsonpath='{.items[0].metadata.name}')
   kubectl -n capm3-system port-forward ${CAPM3_POD} 8443:8443
   ```

1. Scrape the metrics endpoint using one of the following methods:

   Insecure (http):

   ```bash
   curl http://localhost:8443/metrics
   ```

   Secure (https):

   ```bash
   TOKEN=$(kubectl create token default)
   curl https://localhost:8443/metrics --header "Authorization: Bearer $TOKEN" -k
   ```

### Using a test Pod in the cluster

For testing within the cluster environment, you can deploy a test pod to scrape
metrics directly:

1. Create a test pod with curl installed:

   ```YAML
    cat <<EOF | kubectl apply -f -
    apiVersion: v1
    kind: Pod
    metadata:
      name: metrics-test
      namespace: capm3-system
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: metrics-test
        image: curlimages/curl:latest
        command: ["sleep", "3600"]
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
      restartPolicy: Never
    EOF
   ```

1. Get the CAPM3 controller manager pod IP:

   ```bash
   CAPM3_POD_IP=$(kubectl -n capm3-system get pods -l control-plane=controller-manager -o jsonpath='{.items[0].status.podIP}')
   ```

1. Scrape metrics from within the test pod using one of the following methods:

   Insecure (http):

   ```bash
   kubectl exec -n capm3-system metrics-test -- curl -s http://${CAPM3_POD_IP}:8443/metrics
   ```

   Secure (https):

   ```bash
   TOKEN=$(kubectl create token default -n capm3-system)
   kubectl exec -n capm3-system metrics-test -- curl -s https://${CAPM3_POD_IP}:8443/metrics --header "Authorization: Bearer $TOKEN" -k
   ```

## 2. Prometheus integration

For production environments, integrate CAPM3 metrics with Prometheus for
continuous monitoring, alerting, and long-term storage. Before configuring
Prometheus ensure that `--insecure-diagnostics` is **not** set to enable
the HTTPS-based endpoint for metrics.

### Using Prometheus Helm chart (recommended)

The simplest way to integrate with Prometheus is using the official Prometheus
Helm chart. The Prometheus Helm chart deploys the required ClusterRole out-of-the-box.
Prometheus will automatically discover and scrape CAPM3 metrics
because CAPM3 advertises its metrics endpoint through the following Pod annotations:

```yaml
annotations:
  prometheus.io/path: /metrics
  prometheus.io/port: "8443"
  prometheus.io/scrape: "true"
```

## Available Metrics

CAPM3 exposes standard controller-runtime metrics, including:

- API Request Metrics: Request rates, latencies, and error rates
- Work queue Metrics: Queue depth, processing time, and retry counts
- Controller Metrics: Reconciliation counts and durations
- Go Runtime Metrics: Memory usage, go routines, and GC statistics

For a complete list of available metrics, scrape the `/metrics` endpoint and
inspect the output.
