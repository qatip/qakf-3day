   #!/bin/bash
   
   OUTPUT="reset-cluster.sh"
   
   kubectl get namespaces \
     --no-headers \
     -o custom-columns=":metadata.name" \
     | sort    /tmp/baseline-namespaces.txt
   
   cat    "$OUTPUT" <<'SCRIPT'
   #!/bin/bash
   
   set -e
   
   echo "Resetting the Kubernetes lab environment..."
   
   BASELINE_NAMESPACES=$(cat <<'NAMESPACES'
   SCRIPT
   
   cat /tmp/baseline-namespaces.txt      "$OUTPUT"
   
   cat      "$OUTPUT" <<'SCRIPT'
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
   SCRIPT
   
   chmod +x "$OUTPUT"
   rm -f /tmp/baseline-namespaces.txt
   
   echo "Created $OUTPUT"
   echo "Delegates can reset the cluster using:"
   echo "  ./$OUTPUT"
   EOF