# Chaos Test Results

All tests run on AWS EKS, Kubernetes v1.35, 2-node cluster.

---

## Test 1 — Pod Kill

**Command:**
```bash
kubectl delete pod -l app=postgres,role=primary --force --grace-period=0
```

**Expected:** New pod spawns automatically  
**Result:** New pod Running in **~3 seconds**  
**Status:** PASSED

---

## Test 2 — CPU Spike (HPA)

**Command:**
```bash
kubectl apply -f chaos-tests/cpu-load.yaml
kubectl get hpa -w
```

**Expected:** HPA scales pods when CPU > 50%  
**Result:**
```
cpu: 0%/50%   → replicas: 1
cpu: 30%/50%  → replicas: 1
cpu: 250%/50% → replicas: 4
cpu: 132%/50% → replicas: 5
cpu: 67%/50%  → replicas: 5  (load distributed)
```
**Time to scale:** ~90 seconds  
**Status:** PASSED

---

## Test 3 — Nuclear (All Pods Deleted)

**Command:**
```bash
kubectl delete pods --all --force --grace-period=0
```

**Pods deleted:**
- chaos-load
- crash-app
- php-apache (5 replicas)
- postgres-primary
- postgres-replica

**Expected:** All deployments self-restore  
**Result:** Every pod recreated automatically within 30 seconds  
**Status:** PASSED

---

## Test 4 — Memory Stress

**Command:**
```bash
kubectl apply -f chaos-tests/memory-stress.yaml
```

**Expected:** Grafana captures spike, Slack alert fires  
**Result:** Memory usage 648 MiB → 720 MiB captured in Grafana dashboard  
**Alert fired to Slack:** Yes, real-time  
**Status:** PASSED

---

## Summary

| Test | Scenario | Result | Recovery Time |
|------|----------|--------|---------------|
| 1 | Pod kill | PASSED | 3 seconds |
| 2 | CPU spike | PASSED | 90 seconds |
| 3 | Nuclear deletion | PASSED | 30 seconds |
| 4 | Memory stress | PASSED | Real-time alert |

**4/4 tests passed. Zero manual interventions.**
