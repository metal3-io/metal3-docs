#!/usr/bin/env bash

kind create cluster --config kind.yaml
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml

kubectl apply -k ironic
kubectl apply -k bmo
