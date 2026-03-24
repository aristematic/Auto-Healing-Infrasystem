# Self-Healing Kubernetes Infrastructure on AWS EKS

> Infrastructure that detects failures, recovers automatically, and notifies your team — without human intervention.

![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.35-blue?logo=kubernetes)
![AWS EKS](https://img.shields.io/badge/AWS-EKS-orange?logo=amazonaws)
![Prometheus](https://img.shields.io/badge/Prometheus-monitoring-red?logo=prometheus)
![Grafana](https://img.shields.io/badge/Grafana-dashboards-yellow?logo=grafana)
![Helm](https://img.shields.io/badge/Helm-v4.0-blue?logo=helm)

---

## What This Does

| Failure Scenario | Detection | Response | Time to Recover |
|---|---|---|---|
| CPU > 50% | Prometheus + HPA | Auto-scale pods 1→5 | < 90 seconds |
| Pod crash | LivenessProbe | Auto-restart + Slack alert | < 15 seconds |
| DB primary down | PrometheusRule | Failover to replica | < 10 seconds |
| Memory spike | Prometheus | Grafana alert + Slack | Real-time |

**Chaos test results: 4/4 passed. Zero manual interventions. Zero downtime.**

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    AWS EKS Cluster                       │
│                                                          │
│  ┌──────────────┐    ┌──────────────┐                   │
│  │  Prometheus  │───▶│  Grafana     │                   │
│  │  (metrics)   │    │  (dashboards)│                   │
│  └──────┬───────┘    └──────────────┘                   │
│         │                                                │
│         ▼                                                │
│  ┌──────────────┐    ┌──────────────┐                   │
│  │ Alertmanager │───▶│    Slack     │                   │
│  │  (routing)   │    │  (alerts)    │                   │
│  └──────┬───────┘    └──────────────┘                   │
│         │                                                │
│    ┌────┴─────┬──────────────┐                          │
│    ▼          ▼              ▼                           │
│  ┌────┐  ┌────────┐  ┌─────────────┐                   │
│  │HPA │  │Liveness│  │DB Failover  │                   │
│  │Auto│  │Probe   │  │(primary→    │                   │
│  │scale│  │Restart │  │ replica)    │                   │
│  └────┘  └────────┘  └─────────────┘                   │
└─────────────────────────────────────────────────────────┘
```

---

## Prerequisites

- AWS CLI configured (`aws configure`)
- EKS cluster running
- `kubectl` connected to cluster
- `helm` v3+ installed

```bash
# Verify connection
kubectl get nodes
helm version
```

---

## Quick Start

### 1. Clone the repo

```bash
git clone https://github.com/YOUR_USERNAME/self-healing-k8s.git
cd self-healing-k8s
```

### 2. Deploy monitoring stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=admin123 \
  --set prometheus.prometheusSpec.retention=7d
```

### 3. Fix metrics-server for EKS

```bash
kubectl apply -f autoscaling/metrics-server-patch.yaml
kubectl rollout restart deployment/metrics-server -n kube-system
```

### 4. Deploy alert rules

```bash
kubectl apply -f monitoring/alert-rules.yaml
kubectl apply -f monitoring/db-alert-rules.yaml
```

### 5. Configure Slack alerts

```bash
# Edit monitoring/alertmanager-slack.yaml
# Replace YOUR_SLACK_WEBHOOK_URL with actual webhook

kubectl apply -f monitoring/alertmanager-slack.yaml
kubectl rollout restart statefulset/alertmanager-monitoring-kube-prometheus-alertmanager -n monitoring
```

### 6. Deploy test workloads

```bash
kubectl apply -f autoscaling/hpa-demo.yaml
kubectl apply -f self-healing/crash-app.yaml
kubectl apply -f database/postgres-primary.yaml
kubectl apply -f database/postgres-replica.yaml
```

### 7. Run chaos tests

```bash
# CPU spike test
kubectl apply -f chaos-tests/cpu-load.yaml

# Pod kill test
kubectl delete pod -l app=postgres,role=primary --force

# Nuclear test (delete everything)
kubectl delete pods --all --force --grace-period=0

# Memory stress test
kubectl apply -f chaos-tests/memory-stress.yaml
```

---

## Repository Structure

```
self-healing-k8s/
├── monitoring/
│   ├── alert-rules.yaml          # PodCrashLooping, PodNotReady rules
│   ├── db-alert-rules.yaml       # PostgreSQL health rules
│   └── alertmanager-slack.yaml   # Slack webhook config
├── autoscaling/
│   ├── hpa-demo.yaml             # HPA + php-apache deployment
│   └── metrics-server-patch.yaml # EKS-specific metrics-server fix
├── self-healing/
│   └── crash-app.yaml            # LivenessProbe crash demo
├── database/
│   ├── postgres-primary.yaml     # Primary PostgreSQL
│   ├── postgres-replica.yaml     # Replica PostgreSQL
│   └── failover.sh               # Manual failover script
├── chaos-tests/
│   ├── cpu-load.yaml             # CPU spike generator
│   └── memory-stress.yaml        # Memory stress injector
└── docs/
    ├── SETUP.md                  # Detailed setup guide
    └── CHAOS_RESULTS.md          # Test results + screenshots
```

---

## Chaos Test Results

### Test 1 — Pod kill
```bash
kubectl delete pod -l app=postgres,role=primary --force
# Result: New pod Running in 3 seconds
```

### Test 2 — CPU spike
```bash
kubectl apply -f chaos-tests/cpu-load.yaml
kubectl get hpa -w
# Result: cpu 250%/50% → replicas scaled 1→5 automatically
```

### Test 3 — Nuclear (all pods deleted)
```bash
kubectl delete pods --all --force --grace-period=0
# Result: Kubernetes self-restored entire cluster
```

### Test 4 — Memory stress
```bash
kubectl apply -f chaos-tests/memory-stress.yaml
# Result: Grafana captured spike, Slack alerted in real-time
```

---

## Key Learnings

- `--kubelet-insecure-tls` is required for metrics-server on EKS — without it HPA stays `<unknown>`
- Git Bash on Windows injects local paths into pod commands — use heredoc `cat <<'EOF'` instead
- `restartPolicy: Always` is non-negotiable for self-healing workloads
- Simple service selector switch (`kubectl patch`) is enough for DB failover at this scale
- Chaos test before you trust. If you haven't broken it, you don't know if it works.

---

## What's Next

- [ ] Istio service mesh — traffic management + mTLS
- [ ] ArgoCD — GitOps based deployments
- [ ] Vertical Pod Autoscaler (VPA)
- [ ] PodDisruptionBudgets for zero-downtime upgrades
- [ ] Velero for cluster backup

---

## Stack

`AWS EKS` `Kubernetes v1.35` `Prometheus` `Grafana` `Alertmanager` `Helm` `HPA` `PostgreSQL` `Slack`
