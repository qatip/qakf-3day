# Lab 6a.3 – Publishing and Troubleshooting a Governed Application

## Learning Objectives

By the end of this lab you will be able to:

- Create an Ingress resource.
- Explain how Ingress backend resolution works.
- Troubleshoot failed ingress routing.
- Use an `ExternalName` Service to bridge namespaces.
- Explain why `ExternalName` Services depend on DNS.
- Update a NetworkPolicy to permit DNS egress.
- Verify that a locked-down application is reachable through an ingress controller.

---

# Background

In the previous lab you deployed a compliant webserver into the `webserver` namespace.

The application is now running, but it is only exposed internally through a ClusterIP Service.

In this lab you will publish that application through the NGINX Ingress Controller running in the `ingress` namespace.

This is where several Kubernetes concepts meet:

- Ingress
- Services
- Namespaces
- DNS
- NetworkPolicies
- NodePort
- Ingress Controllers

The lab deliberately introduces a realistic routing problem. The application is healthy, but the request path is incomplete. Your job is to follow the request, identify each failure point and progressively fix the design.

---

# Request Path

By the end of the lab, traffic should follow this path:

```text
Browser
  |
  v
NodePort on cluster node
  |
  v
NGINX Ingress Controller
  |
  v
Service named webserver in the ingress namespace
  |
  v
ExternalName DNS alias
  |
  v
Service named webserver in the webserver namespace
  |
  v
webserver Pods on port 8080
```

At the start of the lab, several parts of this path are missing or blocked.

---

# Starting Point

Confirm that the webserver is running.

```bash
kubectl get deployment -n webserver
kubectl get pods -n webserver
kubectl get svc -n webserver
```

Expected result:

```text
NAME        READY   UP-TO-DATE   AVAILABLE
webserver   5/5     5            5
```

The webserver Service should be listening on port `8080`.

Reconfigure the NGINX Ingress Controller:

```bash
kubectl delete networkpolicy ingress-netpol -n ingress
kubectl rollout restart deployment nginx-ingress-controller -n ingress
```

---

# Phase 1 – Create the Initial Ingress Resource

## Why?

An Ingress resource defines HTTP routing rules.

It does not expose an application by itself. Instead, the Ingress Controller watches the Ingress resource and configures itself to route traffic based on those rules.

Create the Ingress manifest:

```bash
kubectl create ingress new-ingress \
  -n ingress \
  --class=nginx \
  --rule="/*=webserver:8080" \
  --dry-run=client -o yaml > ingress.yaml
```

Review the generated file:

```bash
nano ingress.yaml
```

It should look similar to this:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: new-ingress
  namespace: ingress
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - backend:
          service:
            name: webserver
            port:
              number: 8080
        path: /
        pathType: Prefix
```

Apply it:

```bash
kubectl apply -f ingress.yaml
```

Verify:

```bash
kubectl get ingress -n ingress
kubectl describe ingress new-ingress -n ingress
```

### Behind the Scenes

The Ingress resource has been created in the `ingress` namespace.

That detail matters.

When an Ingress references a backend Service by name, Kubernetes resolves that Service name in the same namespace as the Ingress resource.

So this backend:

```yaml
service:
  name: webserver
```

means:

```text
webserver.ingress.svc.cluster.local
```

It does **not** mean:

```text
webserver.webserver.svc.cluster.local
```

---

# Phase 2 – Find the Entry Point

## Why?

The lab cluster is not using a cloud load balancer, so the Ingress Controller Service will not receive an external cloud IP address.

Instead, traffic reaches the controller through a NodePort.

List the ingress services:

```bash
kubectl get svc -n ingress
```

Look for the HTTP port mapping.

Example:

```text
80:30xxx/TCP
```

The high-numbered port after the colon is the NodePort.

Open the following URL in a browser:

```text
http://<cluster-node-ip>:<nodeport>
```

You may not see the NGINX welcome page yet.

That is expected.

### Behind the Scenes

A NodePort exposes a Service on a high-numbered port on each cluster node.

The traffic path is:

```text
Browser
  |
  v
Node IP and NodePort
  |
  v
Ingress Controller Service
  |
  v
Ingress Controller Pod
```

At this point, traffic can reach the ingress controller, but the controller may not yet be able to reach the backend application.

---

# Phase 3 – Prove the Application Is Healthy

Before blaming Ingress, confirm that the backend application is actually working.

```bash
kubectl get pods -n webserver
kubectl get svc -n webserver
kubectl get endpoints -n webserver
```

Check the webserver logs:

```bash
kubectl logs -n webserver -l app=webserver
```

### Investigation Point

If the Pods are running and the Service has endpoints, the application itself is healthy.

The problem is therefore somewhere in the path between the Ingress Controller and the backend Service.

---

# Phase 4 – Understand the Namespace Boundary

The Ingress was created in the `ingress` namespace.

Its backend refers to a Service called:

```text
webserver
```

But there is no Service called `webserver` in the `ingress` namespace.

The real Service exists in the `webserver` namespace.

Check both namespaces:

```bash
kubectl get svc -n ingress
kubectl get svc -n webserver
```

You should see that the backend Service exists here:

```text
webserver.webserver.svc.cluster.local
```

but the Ingress is trying to resolve this:

```text
webserver.ingress.svc.cluster.local
```

### Behind the Scenes

Ingress backends are namespace-local.

This prevents an Ingress in one namespace from casually pointing at Services in another namespace. In multi-team clusters, that behaviour is intentional because it avoids accidental cross-namespace exposure.

---

# Phase 5 – Create an ExternalName Service

## Why?

To bridge the namespace boundary, you will create a Service named `webserver` inside the `ingress` namespace.

This Service will not select Pods directly. Instead, it will act as a DNS alias pointing to the real Service in the `webserver` namespace.

Review the provided manifest:

```bash
nano ~/qakf-3day/solutions/lab6a/ename_svc.yaml
```

It should look like this:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webserver
  namespace: ingress
spec:
  type: ExternalName
  externalName: webserver.webserver.svc.cluster.local
  ports:
  - port: 8080
    targetPort: 8080
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

The application may still fail.

That is also expected.

You have fixed the namespace lookup problem, but now the Ingress Controller must perform DNS resolution.

---

# Phase 6 – Understand the DNS Dependency

An `ExternalName` Service is effectively a DNS alias.

The Ingress Controller now resolves:

```text
webserver.ingress.svc.cluster.local
```

which points to:

```text
webserver.webserver.svc.cluster.local
```

Kubernetes DNS normally runs in the `kube-system` namespace as Pods labelled:

```yaml
k8s-app: kube-dns
```

However, the `ingress` namespace has an egress NetworkPolicy. That policy currently allows traffic towards the webserver namespace, but it does not allow DNS egress to kube-dns.

So the Ingress Controller cannot resolve the backend name.

### Behind the Scenes

NetworkPolicies do not only affect application traffic.

They can also block infrastructure dependencies such as:

- DNS
- metrics collection
- logging agents
- service mesh control planes
- external APIs

This is a common real-world troubleshooting issue.

---

# Phase 7 – Update the Ingress NetworkPolicy

Open the ingress NetworkPolicy:

```bash
nano netpol_ingress.yaml
```

It should already allow egress traffic to the `webserver` namespace on TCP port `8080`.

Add a second egress rule allowing DNS lookups to kube-dns in the `kube-system` namespace.

Use this completed version if required:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ingress-netpol
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          app: webserver
    ports:
    - protocol: TCP
      port: 8080
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

Apply the updated policy:

```bash
kubectl apply -n ingress -f netpol_ingress.yaml
```

Verify:

```bash
kubectl describe networkpolicy ingress-netpol -n ingress
```

### Behind the Scenes

The first egress rule allows the controller to reach the application.

The second egress rule allows the controller to resolve DNS names.

Both are required for this design to work.

---

# Phase 8 – Test the Published Application

Reload the browser:

```text
http://<cluster-node-ip>:<nodeport>
```

You should now see the default NGINX welcome page.

You can also test from the command line:

```bash
curl http://<cluster-node-ip>:<nodeport>
```

If the request still fails, follow the troubleshooting sequence below.

---

# Troubleshooting Sequence

Use this order. It follows the request path from outside the cluster to the backend Pods.

## 1. Check the NodePort

```bash
kubectl get svc -n ingress
```

Confirm that you are using the correct high-numbered port.

## 2. Check the Ingress Controller Pods

```bash
kubectl get pods -n ingress
kubectl logs -n ingress -l app.kubernetes.io/name=nginx-ingress
```

## 3. Check the Ingress resource

```bash
kubectl describe ingress new-ingress -n ingress
```

Confirm that the backend points to:

```text
webserver:8080
```

## 4. Check the ExternalName Service

```bash
kubectl get svc webserver -n ingress -o yaml
```

Confirm:

```yaml
type: ExternalName
externalName: webserver.webserver.svc.cluster.local
```

## 5. Check the real backend Service

```bash
kubectl get svc webserver -n webserver -o yaml
kubectl get endpoints webserver -n webserver
```

Confirm that the Service exposes port `8080` and has endpoints.

## 6. Check the webserver Pods

```bash
kubectl get pods -n webserver --show-labels
```

Confirm the Pods are running and labelled:

```yaml
app: webserver
```

## 7. Check NetworkPolicies

```bash
kubectl get networkpolicy -A
kubectl describe networkpolicy ingress-netpol -n ingress
kubectl describe networkpolicy webserver-netpol -n webserver
```

Confirm that:

- The ingress namespace can egress to the webserver namespace on TCP 8080.
- The ingress namespace can egress to kube-dns on TCP/UDP 53.
- The webserver namespace allows ingress from the ingress namespace on TCP 8080.

---

# Final Expected State

By the end of this lab you should have the following resources.

## Namespaces

```bash
kubectl get ns webserver ingress --show-labels
```

## Webserver Deployment

```bash
kubectl get deployment -n webserver
```

Expected:

```text
webserver   5/5
```

## Webserver Service

```bash
kubectl get svc -n webserver
```

Expected:

```text
webserver   ClusterIP   ...   8080/TCP
```

## Ingress Controller

```bash
kubectl get pods -n ingress
kubectl get svc -n ingress
```

## ExternalName Service

```bash
kubectl get svc webserver -n ingress
```

Expected type:

```text
ExternalName
```

## NetworkPolicies

```bash
kubectl get networkpolicy -A
```

Expected:

```text
ingress     ingress-netpol
webserver   webserver-netpol
```

---

# Knowledge Check

1. Why did the first Ingress configuration fail?
2. Why does an Ingress backend resolve Services in the same namespace as the Ingress?
3. What problem does the `ExternalName` Service solve?
4. Why does `ExternalName` require DNS access?
5. Why did the ingress NetworkPolicy need both application egress and DNS egress?
6. Why is the application still protected even though it is published through Ingress?

---

# Summary

You have now published a governed application through an ingress controller while preserving namespace separation and network controls.

The final design is intentionally more complex than simply exposing a Service directly, but it demonstrates several real production concerns:

- Application namespaces should remain isolated.
- Ingress controllers often run in dedicated namespaces.
- Cross-namespace routing requires deliberate design.
- DNS is a critical dependency.
- NetworkPolicies must account for both application traffic and infrastructure traffic.

In this lab you followed the request path step by step, fixed each missing piece and proved that the application could be reached safely through the ingress layer.

This completes Lab 6a and sets the foundation for the Kyverno policy-as-code labs that follow.
