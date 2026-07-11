# Lab 6a.3 – Publishing the Webserver Through Ingress

## Learning Objectives

By the end of this lab you will be able to:

- Create an Ingress resource.
- Publish an application through an NGINX Ingress Controller.
- Explain why an Ingress backend Service must be in the same namespace as the Ingress.
- Identify the NodePort used to reach the Ingress Controller.
- Test and troubleshoot the complete request path.

---

# Background

In Lab 6a.1 you created a governed Kubernetes platform.

In Lab 6a.2 you deployed a compliant NGINX workload into the `webserver` namespace and exposed it internally through a ClusterIP Service.

In this lab you will publish that application through the NGINX Ingress Controller running in the `ingress` namespace.

The Ingress Controller and the Ingress resource do not need to be in the same namespace.

The Ingress resource will be created in the `webserver` namespace because its backend Service also exists in that namespace.

---

# Request Path

By the end of the lab, traffic should follow this path:

```text
Browser or curl
      |
      v
webserver.<PUBLIC-IP>.sslip.io
      |
      v
Cluster node public IP
      |
      v
Ingress Controller NodePort
      |
      v
NGINX Ingress Controller
      |
      v
webserver Service in the webserver namespace
      |
      v
webserver Pods on TCP 8080
```

---

# Starting Point

Confirm that the resources created in the previous labs still exist.

```bash
kubectl get deployment -n webserver
kubectl get pods -n webserver
kubectl get svc -n webserver
kubectl get pods -n ingress
kubectl get svc -n ingress
```

You should have:

- Five running webserver Pods.
- One ClusterIP Service called `webserver` in the `webserver` namespace.
- Running NGINX Ingress Controller Pods in the `ingress` namespace.
- An Ingress Controller Service exposing HTTP through a NodePort.

---

# Phase 1 – Remove Any Previous Lab Attempts

## Why?

This lab uses a deliberately simple and reliable design.

The Ingress Controller remains in the `ingress` namespace, while the Ingress resource is created in the `webserver` namespace alongside its backend Service.

Remove any resources left behind by previous attempts:

```bash
kubectl delete networkpolicy ingress-netpol -n ingress --ignore-not-found
kubectl delete ingress new-ingress -n ingress --ignore-not-found
kubectl delete svc webserver -n ingress --ignore-not-found
kubectl delete ingress new-ingress -n webserver --ignore-not-found
```

Confirm that the Ingress Controller is healthy:

```bash
kubectl get pods -n ingress
```

Check recent controller logs:

```bash
kubectl logs -n ingress   -l app.kubernetes.io/name=nginx-ingress   --since=1m   --prefix
```

You should not see repeated errors showing that the controller cannot reach:

```text
https://10.96.0.1:443
```

If the Pods are running but old errors are still visible, restart the DaemonSet:

```bash
kubectl rollout restart daemonset nginx-ingress-controller -n ingress
kubectl rollout status daemonset nginx-ingress-controller -n ingress
```

---

# Phase 2 – Determine the Public IP Address

The hostname used by the Ingress must resolve to the public IP address of the cluster node.

Display the public IP address:

```bash
curl ifconfig.io
```

Make a note of the returned address.

For example:

```text
35.91.57.164
```

You will use this address with `sslip.io`.

For example:

```text
webserver.35.91.57.164.sslip.io
```

`sslip.io` resolves a hostname containing an IP address back to that IP address.

---

# Phase 3 – Create the Ingress Resource

Create a new file:

```bash
nano ingress.yaml
```

Add the following manifest, replacing `<PUBLIC-IP>` with the address returned in the previous phase:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: new-ingress
  namespace: webserver
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

Save the file and exit `nano`.

Apply the Ingress:

```bash
kubectl apply -f ingress.yaml
```

Verify it:

```bash
kubectl get ingress -n webserver
kubectl describe ingress new-ingress -n webserver
```

The backend should show the `webserver` Service and its Pod endpoints.

It should not show:

```text
<error: endpoints "webserver" not found>
```

---

# Behind the Scenes

The Ingress resource is in the `webserver` namespace.

Its backend contains:

```yaml
service:
  name: webserver
```

Kubernetes therefore looks for this Service:

```text
Service: webserver
Namespace: webserver
```

That Service already exists and has endpoints for the five running webserver Pods.

The NGINX Ingress Controller can run in a different namespace. It watches Ingress resources and configures routing for them.

---

# Phase 4 – Find the Ingress Controller NodePort

List the Services in the `ingress` namespace:

```bash
kubectl get svc -n ingress
```

Locate the HTTP port mapping.

For example:

```text
80:30486/TCP
```

The high-numbered port after the colon is the NodePort.

In this example, the NodePort is:

```text
30486
```

---

# Phase 5 – Test the Published Application

Open the following address in a browser:

```text
http://webserver.<PUBLIC-IP>.sslip.io:<NODEPORT>
```

For example:

```text
http://webserver.35.91.57.164.sslip.io:30486
```

You should see the NGINX welcome page.

You can also test from the command line:

```bash
curl http://webserver.<PUBLIC-IP>.sslip.io:<NODEPORT>
```

A successful response should contain HTML from the NGINX welcome page.

---

# Phase 6 – Verify the Complete Request Path

Check each part of the request path.

## 1. Ingress Controller Pods

```bash
kubectl get pods -n ingress
```

The controller Pods should be `Running`.

## 2. Ingress Controller Service

```bash
kubectl get svc -n ingress
```

Confirm that port 80 is exposed through a NodePort.

## 3. Ingress Resource

```bash
kubectl describe ingress new-ingress -n webserver
```

Confirm:

- The host matches the `sslip.io` hostname.
- The backend is `webserver:8080`.
- Pod endpoint addresses are displayed.

## 4. Backend Service

```bash
kubectl get svc webserver -n webserver
kubectl describe svc webserver -n webserver
```

Confirm that the Service exposes TCP 8080.

## 5. Service Endpoints

```bash
kubectl get endpoints webserver -n webserver
```

Confirm that endpoint addresses are listed.

## 6. Webserver Pods

```bash
kubectl get pods -n webserver
```

Confirm that all five Pods are running.

## 7. Webserver NetworkPolicy

```bash
kubectl describe networkpolicy webserver-netpol -n webserver
```

Confirm that TCP 8080 is allowed from namespaces labelled:

```text
app=nginx-ingress
```

Check the label on the `ingress` namespace:

```bash
kubectl get namespace ingress --show-labels
```

---

# Troubleshooting

Follow the request path in order.

## The hostname does not resolve

Check the public IP:

```bash
curl ifconfig.io
```

Confirm that the IP embedded in the hostname is correct.

## The connection is refused or times out

Check the NodePort:

```bash
kubectl get svc -n ingress
```

Confirm that you are using the HTTP NodePort associated with port 80.

Also confirm that the cloud firewall or security group allows inbound access to that NodePort.

## The Ingress has no backend endpoints

Run:

```bash
kubectl describe ingress new-ingress -n webserver
kubectl get svc webserver -n webserver
kubectl get endpoints webserver -n webserver
```

Confirm that the Ingress and Service are both in the `webserver` namespace.

## The Ingress Controller is not responding to changes

Check the logs:

```bash
kubectl logs -n ingress   -l app.kubernetes.io/name=nginx-ingress   --since=5m   --prefix
```

If the logs show repeated API server timeouts, confirm that no egress NetworkPolicy exists in the `ingress` namespace:

```bash
kubectl get networkpolicy -n ingress
```

Delete any old ingress egress policy:

```bash
kubectl delete networkpolicy ingress-netpol -n ingress --ignore-not-found
```

Restart the controller:

```bash
kubectl rollout restart daemonset nginx-ingress-controller -n ingress
kubectl rollout status daemonset nginx-ingress-controller -n ingress
```

## The Ingress returns an NGINX error page

Check the backend application:

```bash
kubectl get pods -n webserver
kubectl get svc,endpoints -n webserver
kubectl logs -n webserver -l app=webserver
```

---

# Final Expected State

## Webserver workload

```bash
kubectl get deployment,pods,svc -n webserver
```

Expected:

- One Deployment.
- Five running Pods.
- One ClusterIP Service on TCP 8080.

## Ingress resource

```bash
kubectl get ingress -n webserver
```

Expected:

```text
new-ingress
```

## Ingress Controller

```bash
kubectl get daemonset,pods,svc -n ingress
```

Expected:

- A healthy DaemonSet.
- Running controller Pods.
- A Service exposing port 80 through a NodePort.

## NetworkPolicies

```bash
kubectl get networkpolicy -A
```

Expected:

```text
webserver   webserver-netpol
```

There should be no `ingress-netpol` in the `ingress` namespace.

---

# Knowledge Check

1. Why is the Ingress resource created in the `webserver` namespace?
2. Does the Ingress Controller have to run in the same namespace as the Ingress resource?
3. What is the purpose of the NodePort?
4. Why is the `sslip.io` hostname included in the Ingress rule?
5. What is the complete request path from the browser to a webserver Pod?
6. Why does the webserver NetworkPolicy still allow the request?

---

# Summary

You have successfully published the governed webserver application through the NGINX Ingress Controller.

The Ingress resource was created in the `webserver` namespace alongside its backend Service, while the Ingress Controller remained in its dedicated `ingress` namespace.

The final request path is:

```text
Browser
  |
  v
sslip.io hostname
  |
  v
Cluster node public IP and NodePort
  |
  v
NGINX Ingress Controller
  |
  v
webserver ClusterIP Service
  |
  v
webserver Pods on TCP 8080
```

The application remains protected by the NetworkPolicy created in Lab 6a.1, which only permits TCP 8080 traffic from the labelled `ingress` namespace.
