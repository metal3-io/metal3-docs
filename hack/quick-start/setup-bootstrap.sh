#!/usr/bin/env bash

kind create cluster --config "${QUICK_START_BASE}/kind.yaml"

# (Optional) Initialize CAPM3. This is only needed for scenario 2, but it also installs
# cert-manager, which is needed for pretty much everything else.
# If you skip this, make sure you install cert-manager separately!
clusterctl init --infrastructure=metal3 --ipam=metal3

kubectl apply -k "${QUICK_START_BASE}/irso"
kubectl -n ironic-standalone-operator-system wait --for=condition=Available --timeout=300s deploy/ironic-standalone-operator-controller-manager

# Now we can deploy Ironic and BMO
kubectl create ns baremetal-operator-system
# Apply Ironic with retry logic (up to 5 attempts with 10 second delays).
# The IrSO webhook is not guaranteed to be ready when the IrSO deployment is,
# so some retries may be needed.
MAX_RETRIES=5
RETRY_DELAY=10
RETRY_COUNT=0
echo "Applying Ironic configuration..."
while [[ "${RETRY_COUNT}" -lt "${MAX_RETRIES}" ]]; do
  if kubectl apply -k "${QUICK_START_BASE}/ironic"; then
    echo "Successfully applied Ironic configuration"
    break
  else
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Failed to apply Ironic configuration. Retrying in ${RETRY_DELAY} seconds... (Attempt ${RETRY_COUNT}/${MAX_RETRIES})"
    sleep ${RETRY_DELAY}
  fi
done
if [[ "${RETRY_COUNT}" -eq "${MAX_RETRIES}" ]]; then
  echo "ERROR: Failed to apply Ironic configuration after ${MAX_RETRIES} attempts. Exiting."
  exit 1
fi
kubectl apply -k "${QUICK_START_BASE}/bmo"
