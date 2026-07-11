# Lab 6a.3 – Publishing a Governed Application

## Learning Objectives

By the end of this lab you will be able to:

- Create an Ingress resource.
- Publish an application through an NGINX Ingress Controller.
- Explain why Ingress backends are namespace-local.
- Use an `ExternalName` Service to bridge namespaces.
- Follow an HTTP request from a browser to a Kubernetes Pod.
- Troubleshoot common Ingress problems.

---

# Background

In the previous lab you successfully deployed a compliant webserver into the `webserver` namespace.

The application is currently only reachable inside the cluster through a ClusterIP Service.

In this lab you will publish that application using the NGINX Ingress Controller running in the `ingress` namespace.

The lab deliberately starts with an incomplete configuration. You will investigate why it fails before completing the design.

---

# Starting Point

Verify the application and ingress controller are running.

```bash
kubectl get deployment -n webserver
kubectl get pods -n webserver
kubectl get svc -n webserver

kubectl get pods -n ingress
kubectl get svc -n ingress
```

Expected:

- Five running webserver Pods
- A ClusterIP Service called `webserver`
- A running NGINX Ingress Controller

---

# Phase 1 – Create the Ingress Resource

Determine your public IP address:

```bash
curl ifconfig.io
```

Create `ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: new-ingress
  namespace: ingress
spec:
  ingressClassName: nginx
  rules:
  - host: webserver.<PUBLIC-IP>.sslip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: webserver
            port:
              number: 8080
```

Replace `<PUBLIC-IP>` with your own address.

Apply it:

```bash
kubectl apply -f ingress.yaml
kubectl get ingress -n ingress
kubectl describe ingress new-ingress -n ingress
```

You should see an error similar to:

```text
<error: endpoints "webserver" not found>
```

This is expected.

### Behind the Scenes

Ingress backends always reference Services in the same namespace as the Ingress resource.

---

# Phase 2 – Find the Entry Point

Display the ingress Service:

```bash
kubectl get svc -n ingress
```

Locate the HTTP NodePort.

Browse to:

```text
http://webserver.<PUBLIC-IP>.sslip.io:<NODEPORT>
```

The request will fail.

That is expected.

---

# Phase 3 – Verify the Backend

Confirm the application itself is healthy.

```bash
kubectl get pods -n webserver
kubectl get svc -n webserver
kubectl get endpoints -n webserver
kubectl logs -n webserver -l app=webserver
```

If the Service has endpoints, the application is working correctly.

The problem lies between the Ingress Controller and the backend Service.

---

# Phase 4 – Understand Namespace Boundaries

Compare the Services:

```bash
kubectl get svc -n ingress
kubectl get svc -n webserver
```

Notice there is no Service called `webserver` in the `ingress` namespace.

The Ingress references:

```yaml
service:
  name: webserver
```

Since the Ingress lives in the `ingress` namespace, Kubernetes expects a Service called `webserver` in that same namespace.

### Behind the Scenes

The real application Service exists in the `webserver` namespace.

An Ingress cannot directly reference a Service in another namespace.

---

# Phase 5 – Create an ExternalName Service

Review the supplied manifest:

```bash
nano ~/qakf-3day/solutions/lab6a/ename_svc.yaml
```

Apply it:

```bash
kubectl apply -f ~/qakf-3day/solutions/lab6a/ename_svc.yaml
```

Verify:

```bash
kubectl get svc webserver -n ingress
kubectl get svc webserver -n ingress -o yaml
```

Reload the browser.

The application should now load successfully.

### Behind the Scenes

The ExternalName Service creates a Service called `webserver` inside the `ingress` namespace.

Rather than selecting Pods directly, it forwards requests to:

```text
webserver.webserver.svc.cluster.local
```

This bridges the namespace boundary while allowing the Ingress to continue using a local Service reference.

---

# Phase 6 – Follow the Request

The completed request path is now:

```text
Browser
    |
sslip.io DNS
    |
Public IP
    |
NodePort
    |
NGINX Ingress Controller
    |
ExternalName Service (ingress namespace)
    |
ClusterIP Service (webserver namespace)
    |
Pods
```

---

# Phase 7 – Troubleshooting

If the application does not load, investigate in this order.

```bash
kubectl get pods -n ingress
kubectl get ingress -n ingress
kubectl describe ingress new-ingress -n ingress

kubectl get svc webserver -n ingress
kubectl get svc webserver -n webserver
kubectl get endpoints webserver -n webserver

kubectl get networkpolicy -A

kubectl get pods -n webserver
kubectl logs -n webserver -l app=webserver
```

Check that:

- The Ingress Controller is running.
- The Ingress exists.
- The ExternalName Service exists.
- The backend Service has endpoints.
- The webserver NetworkPolicy allows traffic from the labelled `ingress` namespace.

---

# Summary

You have successfully published an application through an NGINX Ingress Controller while maintaining namespace separation.

In this lab you learned that:

- Ingress backends are namespace-local.
- ExternalName Services can bridge namespace boundaries.
- NodePorts provide access into the cluster.
- NetworkPolicies continue to protect the application namespace.
- Following the request path is the quickest way to troubleshoot Ingress problems.
