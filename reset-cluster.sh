#!/bin/bash

set -e

echo "Resetting the Kubernetes lab environment..."

BASELINE_NAMESPACES=$(cat <<'NAMESPACES'
cilium-secrets
default
kube-node-lease
kube-public
kube-system
NAMESPACES
)

kubectl get namespaces \
  --no-headers \
  -o custom-columns=":metadata.name" \
  | sort |
while read -r namespace; do
  if ! echo "$BASELINE_NAMESPACES" | grep -Fxq "$namespace"; then
    echo "Deleting namespace: $namespace"
    kubectl delete namespace "$namespace" --wait=false
  fi
done

echo "Cleaning the default namespace..."

kubectl delete deployment,statefulset,daemonset,replicaset,pod,job,cronjob \
  --all \
  -n default \
  --ignore-not-found

kubectl delete service \
  --all \
  -n default \
  --ignore-not-found

kubectl delete ingress,networkpolicy,pvc,role,rolebinding \
  --all \
  -n default \
  --ignore-not-found

echo
echo "Remaining namespaces:"
kubectl get namespaces

echo
echo "Cluster reset complete."