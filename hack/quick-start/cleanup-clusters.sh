#!/usr/bin/env bash

set -x

# If a cluster was created using Cluster API, delete that first
kubectl delete cluster my-cluster

# Delete all BareMetalHosts with `kubectl delete bmh <name>`. This ensures that
# the servers are cleaned and powered off.
kubectl delete bmh --all

# Delete the management cluster
kind delete cluster
