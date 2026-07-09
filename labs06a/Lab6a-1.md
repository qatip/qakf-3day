# Preparing for Module 6

The next series of labs builds a completely new Kubernetes platform from scratch.

Run the following cleanup commands to remove the resources created during this exercise before continuing to Lab 6a.1.

*** Remove Previous Lab Resources ***

```bash
kubectl delete namespace webserver --ignore-not-found=true
kubectl delete namespace ingress --ignore-not-found=true
kubectl delete ingress new-ingress -n ingress --ignore-not-found=true
kubectl delete svc webserver -n ingress --ignore-not-found=true
helm uninstall nginx-ingress -n ingress 2>/dev/null || true
kubectl delete networkpolicy --all -n webserver --ignore-not-found=true
kubectl delete networkpolicy --all -n ingress --ignore-not-found=true
kubectl delete resourcequota --all -n webserver --ignore-not-found=true
```

Wait for Namespace Removal

``` bash
kubectl get ns
```

If either namespace remains in the Terminating state, wait until it disappears before continuing.

Verify the Starting Point

``` bash
kubectl get ns
kubectl get ingress -A
kubectl get svc -A
kubectl get networkpolicy -A
```

At this point:

webserver should not exist.
ingress should not exist.
No custom NetworkPolicies should remain.
No Ingress resources should remain.
The previous ingress controller should have been removed.

# Lab 6a.1 – Building a Governed Kubernetes Platform

## Learning Objectives

By the end of this lab you will be able to:

- Create isolated Kubernetes namespaces.
- Apply the Restricted Pod Security Standard.
- Configure a ResourceQuota.
- Create and review NetworkPolicies.
- Deploy an NGINX Ingress Controller.
- Explain why each control exists in a production Kubernetes platform.

---

# Background

Before application teams are allowed to deploy workloads, platform engineers normally prepare a Kubernetes cluster with a set of governance controls.

These controls provide:

- Isolation between teams.
- Security guardrails.
- Resource governance.
- Controlled network communication.
- Standardised ingress into the cluster.

Rather than beginning with an application, this lab focuses on building that platform layer. The application itself will not be deployed until the next exercise.

By the end of this lab your cluster will resemble the foundation of a production Kubernetes environment.

---

# Platform Architecture

```text
                    Kubernetes Cluster

   +------------------------------------------------+

        ingress namespace
   +--------------------------------------------+
   | NGINX Ingress Controller                   |
   +--------------------------------------------+
                    |
                    |
             NetworkPolicies
                    |
        webserver namespace
   +--------------------------------------------+
   | Restricted Pod Security                    |
   | ResourceQuota                              |
   | Future Application Workloads               |
   +--------------------------------------------+

   +------------------------------------------------+
```

---

# Phase 1 – Create the Platform Namespaces

## Why?

Namespaces provide logical separation between applications and teams. Although they are not a security boundary by themselves, they allow policies, quotas and RBAC rules to be applied independently.

Create the namespaces:

```bash
kubectl create namespace webserver
kubectl create namespace ingress

kubectl label ns webserver app=webserver
kubectl label ns ingress app=nginx-ingress
```

Verify:

```bash
kubectl get ns --show-labels
```

### Behind the Scenes

The labels you have added are not decorative. Later in this lab, NetworkPolicies will use these labels to identify which namespaces are allowed to communicate.

---

# Phase 2 – Enforce Pod Security

## Why?

The Restricted Pod Security Standard prevents workloads that do not meet Kubernetes security best practices from being admitted into the namespace.

Apply the policy:

```bash
kubectl label ns webserver pod-security.kubernetes.io/enforce=restricted
```

Inspect the namespace:

```bash
kubectl describe namespace webserver
```

### Behind the Scenes

The Pod Security Admission controller evaluates every new Pod before it is created. Non-compliant Pods are rejected before they are scheduled onto a worker node.

---

# Phase 3 – Configure Resource Governance

## Why?

Clusters have finite CPU and memory resources. ResourceQuotas prevent one namespace from consuming more than its fair share.

Create the quota:

```bash
kubectl create quota webserver-quota \
  --hard=pods=5,cpu=2,memory=2G \
  --dry-run=client -o yaml > ws-quota.yaml

kubectl apply -n webserver -f ws-quota.yaml
```

Verify:

```bash
kubectl describe resourcequota webserver-quota -n webserver
kubectl get quota -n webserver -o yaml
```

### Behind the Scenes

A ResourceQuota does not stop you creating a Deployment. Instead, it prevents Pods from being admitted if creating them would exceed the namespace limits.

---

# Phase 4 – Configure NetworkPolicies

## Why?

By default, many Kubernetes environments allow unrestricted Pod-to-Pod communication. NetworkPolicies allow administrators to adopt a least-privilege model by explicitly defining permitted traffic.

Copy the starter manifests:

```bash
cp ~/qakf-3day/solutions/lab6a/netpol_webserver1.yaml netpol_webserver.yaml
cp ~/qakf-3day/solutions/lab6a/netpol_ingress.yaml netpol_ingress.yaml
```

Edit **netpol_webserver.yaml** so that only traffic from the **ingress** namespace is permitted on TCP port **8080**.

Apply the policies:

```bash
kubectl apply -n webserver -f netpol_webserver.yaml
kubectl apply -n ingress -f netpol_ingress.yaml
```

Verify:

```bash
kubectl get networkpolicy -A
kubectl describe networkpolicy -n webserver
```

### Behind the Scenes

NetworkPolicies are enforced by the cluster's Container Network Interface (CNI) plugin. Kubernetes defines the policy model, while the CNI implements the filtering behaviour.

---

# Phase 5 – Deploy the NGINX Ingress Controller

## Why?

An Ingress resource is simply a configuration object. It requires an Ingress Controller to watch those resources and configure a reverse proxy capable of routing traffic into the cluster.

Install the controller:

```bash
helm -n ingress install nginx-ingress \
  oci://ghcr.io/nginx/charts/nginx-ingress \
  --version 2.5.2 \
  --set controller.kind=daemonset
```

Verify:

```bash
kubectl get daemonset -n ingress
kubectl get pods -n ingress
kubectl get svc -n ingress
```

### Behind the Scenes

The controller is deployed as a DaemonSet so that every worker node runs an ingress proxy. This provides resilience and ensures incoming traffic can be accepted regardless of which node receives the connection.

---

# Platform Verification

Your cluster should now contain:

- Two labelled namespaces.
- A Restricted Pod Security Standard.
- A ResourceQuota.
- Two NetworkPolicies.
- A running NGINX Ingress Controller.

Verify everything:

```bash
kubectl get ns --show-labels
kubectl get quota -A
kubectl get networkpolicy -A
kubectl get daemonset -A
kubectl get svc -A
```

---

# Summary

You have completed the platform engineering phase of the exercise.

Rather than deploying an application into an unrestricted cluster, you have first established the governance controls commonly found in enterprise Kubernetes environments.

In the next lab you will attempt to deploy a simple NGINX application into this governed namespace. The deployment will initially fail several times—not because Kubernetes is malfunctioning, but because the controls you have configured are operating exactly as intended.

Each failure will reveal another aspect of Kubernetes security, resource governance or networking, allowing you to progressively adapt the workload until it complies with the platform.
