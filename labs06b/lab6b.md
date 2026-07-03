# Lab 6b -- Policy as Code with Kyverno

## Objectives

In this lab you will:

-   Install the Kyverno policy engine.
-   Create your first Kyverno `ClusterPolicy`.
-   Prevent the deployment of a non-compliant workload.
-   Understand where Kyverno fits within the Kubernetes request
    lifecycle.
-   Return the cluster to its original state.

**Version Note**

 This lab has been developed and tested using the following software versions:

 - Kubernetes v1.31.x
 - Helm 3.x
 - Kyverno Helm Chart **3.5.2**
 - Kyverno Application **1.18.1**

 If using different versions, minor changes to the Kyverno policy syntax may be required.

**Estimated time:** 25--30 minutes

------------------------------------------------------------------------

## Background

Kubernetes validates that submitted resources are syntactically correct,
but it does not enforce organisation-specific standards.

Kyverno extends Kubernetes by acting as an **Admission Controller**,
allowing administrators to validate, modify and generate Kubernetes
resources using familiar YAML syntax.

In this lab you will create a simple validation policy that prevents
container images from using the `latest` tag.

------------------------------------------------------------------------

# 6b.1 Install Kyverno

Add the Helm repository.

``` bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
```

Install Kyverno.

``` bash
helm install kyverno kyverno/kyverno   --namespace kyverno   --create-namespace
```

Verify the installation.

``` bash
kubectl get pods -n kyverno
```

You should see the Admission, Background, Cleanup and Reports
controllers running.

------------------------------------------------------------------------

# 6b.2 Explore the Installation

View the API resources added by Kyverno.

``` bash
kubectl api-resources | grep kyverno
```

Check for existing policies.

``` bash
kubectl get clusterpolicy
kubectl describe clusterpolicy
```

No policies should currently exist.

------------------------------------------------------------------------

# 6b.3 Create Your First Policy

Create a file named **validate.yaml** and copy the following policy.

``` yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy

metadata:
  name: validate-images

spec:
  validationFailureAction: Enforce

  rules:

  - name: no-latest

    match:
      any:
      - resources:
          kinds:
          - Pod

    validate:

      message: "Images tagged 'latest' are prohibited."

      pattern:

        spec:

          containers:

          - image: "!*:latest"
```

## Review

Before applying the policy, review the YAML you have just created and consider...

-   Is this a **Policy** or a **ClusterPolicy**?
-   Which Kubernetes resource type will it evaluate?
-   What behaviour is being enforced?
-   What do you expect to happen if a workload uses `nginx:latest`?

Apply the policy.

``` bash
kubectl apply -f validate.yaml
```

Verify that the policy has been created.

``` bash
kubectl get clusterpolicy
```

------------------------------------------------------------------------

# 6b.4 Test the Policy

Attempt to deploy a workload using the `latest` tag.

``` bash
kubectl create deployment web --image=nginx:latest
```

The deployment should be rejected.

Now deploy a versioned image.

``` bash
kubectl create deployment web --image=nginx:1.29.1
```

Verify the deployment.

``` bash
kubectl get deployment
kubectl get pods
```

### Points to Observe

-   The invalid Deployment was rejected before it was created.
-   The error message originated from the Kyverno policy.
-   The compliant Deployment was accepted without modification.

Consider why this behaviour is preferable to detecting the problem after
the workload has started.

------------------------------------------------------------------------

# 6b.5 Cleanup

Delete the test Deployment.

``` bash
kubectl delete deployment web --ignore-not-found
kubectl delete clusterpolicy validate-images
rm validate.yaml
```

------------------------------------------------------------------------

# Summary

Congratulations.

You have:

-   Installed Kyverno using Helm.
-   Created your first `ClusterPolicy`.
-   Enforced an organisational policy.
-   Prevented the deployment of a non-compliant workload.
-   Restored the cluster to its original state.

The next lab explores the four common Kyverno policy types:

-   Validate
-   Mutate
-   Generate
-   Cleanup
