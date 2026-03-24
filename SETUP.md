# Setup Guide

## Prerequisites

- AWS account with EKS cluster running
- AWS CLI configured (`aws configure`)
- kubectl installed
- Helm v3+ installed
- Git Bash or WSL2 (if on Windows)

## Windows-specific Notes

> If using Git Bash on Windows, always use heredoc syntax for multi-line kubectl commands:
> ```bash
> cat <<'EOF' | kubectl apply -f -
> # your yaml here
> EOF
> ```
> Git Bash injects Windows paths (D:/Git/usr/bin/sh) into pod commands — this breaks containers.
> The heredoc prevents this.

---

## Step 1 — Connect kubectl to EKS

```bash
aws eks update-kubeconfig --region YOUR_REGION --name YOUR_CLUSTER_NAME

# Verify
kubectl get nodes
# Should show nodes in Ready state
```

---

## Step 2 — Add Helm repos

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add stable https://charts.helm.sh/stable
helm repo update
```

---

## Step 3 — Deploy monitoring stack

```bash
kubectl create namespace monitoring

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=admin123 \
  --set prometheus.prometheusSpec.retention=7d

# Wait for all pods to be Running
kubectl get pods -n monitoring -w
```

---

## Step 4 — Fix metrics-server for EKS

Default metrics-server doesn't work on EKS without this fix:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

kubectl patch deployment metrics-server -n kube-system --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"},
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-preferred-address-types=InternalIP"}
]'

kubectl rollout restart deployment/metrics-server -n kube-system

# Verify
kubectl top nodes
```

---

## Step 5 — Configure Slack alerts

1. Go to https://api.slack.com/apps
2. Create New App → From scratch
3. Enable Incoming Webhooks
4. Add webhook to your workspace → select channel
5. Copy the webhook URL

```bash
# Edit alertmanager-slack.yaml — replace YOUR_SLACK_WEBHOOK_URL
kubectl apply -f monitoring/alertmanager-slack.yaml
kubectl rollout restart statefulset/alertmanager-monitoring-kube-prometheus-alertmanager -n monitoring
```

---

## Step 6 — Deploy alert rules

```bash
kubectl apply -f monitoring/alert-rules.yaml
kubectl apply -f monitoring/db-alert-rules.yaml

# Verify
kubectl get prometheusrule -n monitoring
```

---

## Step 7 — Open Grafana

```bash
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
```

Open http://localhost:3000 → admin / admin123

---

## Step 8 — Open Alertmanager

```bash
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-alertmanager 9093:9093
```

Open http://localhost:9093

---

## Cleanup

```bash
kubectl delete deployment php-apache postgres-primary postgres-replica crash-app
kubectl delete pod memory-stress chaos-load --ignore-not-found
kubectl delete hpa php-apache
kubectl delete prometheusrule crash-alerts db-alerts -n monitoring
helm uninstall monitoring -n monitoring
kubectl delete namespace monitoring
```
