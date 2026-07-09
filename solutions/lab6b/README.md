# Lab 6a.2 Deployment Solution Files

These files are complete replacement manifests.

| deploy1.yaml | Initial generated Deployment |
| deploy2.yaml | Adds container securityContext |
| deploy3.yaml | Adds CPU and memory requests/limits |
| deploy4.yaml | Switches to unprivileged NGINX and port 8080 |
| deploy5.yaml | Final quota-compliant Deployment with 5 replicas |

Each file can be applied directly:

```bash
kubectl apply -n webserver -f deployX.yaml
```

The changed sections are bracketed with BEGIN / END comments so you can clearly see what changed between each stage.
