# database/failover.sh
#!/bin/bash
ACTION=${1:-failover}

if [ "$ACTION" = "restore" ]; then
  echo "Restoring traffic to primary..."
  kubectl patch service postgres-svc \
    -p "{\"spec\":{\"selector\":{\"app\":\"postgres\",\"role\":\"primary\"}}}"
  echo "Done — postgres-svc now pointing to primary"
  exit 0
fi

echo "Checking primary status..."
PRIMARY_READY=$(kubectl get pods -l app=postgres,role=primary \
  -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)

if [ "$PRIMARY_READY" != "True" ]; then
  echo "Primary DOWN — initiating failover to replica..."
  kubectl patch service postgres-svc \
    -p "{\"spec\":{\"selector\":{\"app\":\"postgres\",\"role\":\"replica\"}}}"
  echo "Failover complete"
else
  echo "Primary healthy — no action needed"
fi
