# Lab 6b - Introducing Policy as Code with Kyverno

## Objectives

In this lab you will:

-   Install Kyverno into a Kubernetes cluster
-   Create your first ClusterPolicy
-   Observe Kubernetes rejecting a non-compliant Deployment
-   Correct the Deployment so it complies with policy
-   Remove Kyverno and return the cluster to its original state

**Estimated time:** 20--30 minutes

------------------------------------------------------------------------

## Background

Up to this point in the course, Kubernetes has accepted any valid
manifest you have applied.

In many organisations this is not sufficient. Platform teams often need
to enforce organisational standards, such as:

-   Images must not use the `latest` tag.
-   Containers must not run as root.
-   CPU and memory requests/limits must be specified.
-   Images must originate from approved registries.
-   Mandatory labels must exist.

Kyverno is a Kubernetes-native Policy as Code engine that integrates
with the Kubernetes Admission Controller. It evaluates requests before
they are stored in etcd and can validate, mutate, generate or clean up
Kubernetes resources.

------------------------------------------------------------------------

# 6b.1 Install Kyverno

Add the Helm repository:

``` bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
```

Install Kyverno:

``` bash
helm install kyverno kyverno/kyverno \
    --namespace kyverno \
    --create-namespace
```

Verify the installation:

``` bash
kubectl get pods -n kyverno
```

You should see the Admission, Background, Reports and Cleanup
controllers running.

------------------------------------------------------------------------

# 6b.2 Explore the Installation

View the resources Kyverno has added:

``` bash
kubectl api-resources | grep kyverno
```

Check for existing policies:

``` bash
kubectl get clusterpolicy
```

Initially there should be no policies.

------------------------------------------------------------------------

# 6b.3 Create Your First Policy

Create a file named **no-latest.yaml** containing:

``` yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy

metadata:
  name: no-latest

spec:
  validationFailureAction: Enforce

  rules:
  - name: no-latest-tag

    match:
      any:
      - resources:
          kinds:
          - Pod

    validate:
      message: "Images tagged 'latest' are not permitted."

      pattern:
        spec:
          containers:
          - image: "!*:latest"
```

Apply the policy:

``` bash
kubectl apply -f no-latest.yaml
```

Confirm the policy exists:

``` bash
kubectl get clusterpolicy
```

------------------------------------------------------------------------

# 6b.4 Test the Policy

Attempt to deploy an image using the `latest` tag:

``` bash
kubectl create deployment web --image=nginx:latest
```

The deployment should be rejected with a policy violation.

Now deploy a versioned image:

``` bash
kubectl create deployment web --image=nginx:1.29.1
```

Verify the deployment:

``` bash
kubectl get deployment
kubectl get pods
```

------------------------------------------------------------------------

# 6b.5 Discussion

Questions:

-   Why did the first deployment fail?
-   Why did the second deployment succeed?
-   Would Kubernetes itself reject `nginx:latest`?
-   At what point in the Kubernetes request lifecycle does Kyverno
    evaluate requests?

Key takeaway:

    kubectl apply
          ↓
    API Server
          ↓
    Authentication
          ↓
    Authorization (RBAC)
          ↓
    Admission Controllers
          ↓
    Kyverno
          ↓
    Accepted / Rejected
          ↓
    etcd

Kyverno does not replace Kubernetes; it extends the admission process
with organisational policy.

------------------------------------------------------------------------

# 6b.6 Clean Up

Delete the test workload:

``` bash
kubectl delete deployment web --ignore-not-found
kubectl delete deployment nginx --ignore-not-found
kubectl delete pod test-latest --ignore-not-found
```

Delete Kyverno policies:

``` bash
kubectl delete clusterpolicy --all --ignore-not-found
kubectl delete policy --all -A --ignore-not-found
```

Uninstall Kyverno:

``` bash
helm uninstall kyverno -n kyverno
kubectl delete namespace kyverno --ignore-not-found
```

Optional: remove the Kyverno CRDs:

``` bash
kubectl delete crd \
  $(kubectl get crd -o name | grep kyverno.io) \
  --ignore-not-found
```

Verify the cluster has been restored:

``` bash
kubectl get ns
kubectl get all -A
kubectl api-resources | grep kyverno
```

## Notes

-   Kyverno policies are written as Kubernetes YAML resources.
-   `ClusterPolicy` applies cluster-wide, while `Policy` is
    namespace-scoped.
-   Four common policy types are **Validate**, **Mutate**, **Generate**,
    and **Cleanup**.
-   In production, policies are typically introduced in **Audit** mode
    before switching to **Enforce**.
