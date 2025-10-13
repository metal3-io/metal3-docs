#!/usr/bin/env bash

kind create cluster --config kind.yaml

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml

# Ensure that cert-manager is up and running
echo "Waiting for cert-manager to be ready..."

# Wait for cert-manager pods to be ready
kubectl -n cert-manager wait --for=condition=Available deployment/cert-manager-webhook --timeout=300s

# Create a test namespace for cert-manager readiness check
kubectl create namespace cert-manager-test

# Function to check cert-manager readiness with retries
check_cert_manager_ready() {
  local max_attempts=30
  local attempt=1
  local sleep_time=10

  while [ $attempt -le $max_attempts ]; do
    echo "Attempt $attempt/$max_attempts: Creating test Issuer and Certificate..."

    # Create a self-signed Issuer
    if kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: test-selfsigned
  namespace: cert-manager-test
spec:
  selfSigned: {}
EOF
    then
      echo "Issuer created successfully"

      # Create a Certificate using the Issuer
      if kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-certificate
  namespace: cert-manager-test
spec:
  secretName: test-certificate-secret
  isCA: false
  dnsNames:
  - test.example.com
  issuerRef:
    name: test-selfsigned
    kind: Issuer
EOF
      then
        echo "Certificate created successfully"

        # Wait for the Certificate to become ready
        if kubectl wait --for=condition=ready certificate/test-certificate -n cert-manager-test --timeout=60s 2>/dev/null; then
          echo "cert-manager is ready!"
          return 0
        else
          echo "Certificate not ready yet, will retry..."
        fi
      else
        echo "Failed to create Certificate, webhook may not be ready yet..."
      fi
    else
      echo "Failed to create Issuer, webhook may not be ready yet..."
    fi

    # Clean up before retry
    kubectl delete certificate test-certificate -n cert-manager-test --ignore-not-found=true 2>/dev/null
    kubectl delete issuer test-selfsigned -n cert-manager-test --ignore-not-found=true 2>/dev/null

    attempt=$((attempt + 1))
    if [ $attempt -le $max_attempts ]; then
      echo "Waiting ${sleep_time}s before retry..."
      sleep $sleep_time
    fi
  done

  echo "ERROR: cert-manager did not become ready after $max_attempts attempts"
  return 1
}

# Run the readiness check
if check_cert_manager_ready; then
  # Clean up test resources
  kubectl delete namespace cert-manager-test
else
  # Clean up and exit with error
  kubectl delete namespace cert-manager-test
  exit 1
fi


kubectl apply -f https://github.com/metal3-io/ironic-standalone-operator/releases/latest/download/install.yaml

kubectl create ns baremetal-operator-system

kubectl apply -f ironic.yaml
kubectl apply -k bmo
