# Lab 6c -- Advanced Policy as Code with Kyverno

## Objectives

In this lab you will build upon the previous exercise by exploring the
four common Kyverno policy types:

-   Validate
-   Mutate
-   Generate
-   Cleanup

For each policy you will:

-   Review the policy before it is applied.
-   Predict its behaviour.
-   Apply the policy.
-   Observe the results.
-   Discuss where it could be used in a production environment.

**Estimated time:** 45--60 minutes

------------------------------------------------------------------------

# 6c.1 Validation Policies

## Background

Validation policies prevent non-compliant resources from entering the
cluster.

### Exercise

Create **validate.yaml** using the policy provided by your instructor.

## Review

Before applying the policy:

-   Which Kubernetes resource is being evaluated?
-   What condition is being checked?
-   Will this policy **Audit** or **Enforce** compliance?
-   What do you predict will happen if a Deployment uses `nginx:latest`?

Apply the policy.

``` bash
kubectl apply -f validate.yaml
```

Test the policy.

``` bash
kubectl create deployment bad --image=nginx:latest
kubectl create deployment good --image=nginx:1.29.1
```

## Points to Observe

-   Which Deployment was rejected?
-   Which Deployment succeeded?
-   What message did Kyverno return?

### Enterprise Note

Validation policies are commonly introduced in **Audit** mode before
being switched to **Enforce** once administrators are confident they
will not disrupt existing workloads.

Clean up.

``` bash
kubectl delete deployment good --ignore-not-found
kubectl delete clusterpolicy validate-images
```

------------------------------------------------------------------------

# 6c.2 Mutation Policies

## Background

Mutation policies automatically modify resources before they are stored
in Kubernetes.

### Exercise

Create **mutate.yaml** using the policy provided by your instructor.

## Review

Before applying the policy:

-   Which part of the Deployment will be modified?
-   Will the developer need to edit their manifest?
-   What changes do you expect to see afterwards?

Apply the policy.

``` bash
kubectl apply -f mutate.yaml
kubectl create deployment web --image=nginx:1.29.1
```

Inspect the Deployment.

``` bash
kubectl get deployment web -o yaml
```

## Points to Observe

-   Which labels or annotations were added?
-   Did you create them yourself?
-   When were they added?

### Enterprise Note

Mutation policies are frequently used to add standard labels,
annotations, tolerations and image pull secrets across an organisation.

Clean up.

``` bash
kubectl delete deployment web
kubectl delete clusterpolicy add-managed-label
```

------------------------------------------------------------------------

# 6c.3 Generation Policies

## Background

Generation policies automatically create supporting Kubernetes
resources.

### Exercise

Create **generate.yaml** using the policy provided by your instructor.

## Review

Before applying the policy:

-   Which resource triggers this policy?
-   Which new resource will Kyverno create?
-   Where will it be created?

Apply the policy.

``` bash
kubectl apply -f generate.yaml
kubectl create namespace finance
```

Verify the generated resource.

``` bash
kubectl get configmap -n finance
kubectl describe configmap default-config -n finance
```

## Points to Observe

-   Was the ConfigMap created automatically?
-   Would this reduce administrative effort?
-   What other resources could be generated automatically?

### Enterprise Note

Many organisations automatically generate ResourceQuotas, LimitRanges
and default NetworkPolicies whenever a new namespace is created.

Clean up.

``` bash
kubectl delete namespace finance
kubectl delete clusterpolicy namespace-default-config
```

------------------------------------------------------------------------

# 6c.4 Cleanup Policies

## Background

Cleanup policies automatically remove resources that are no longer
required.

### Exercise

Create **cleanup.yaml** using the policy provided by your instructor.

## Review

Before applying the policy:

-   Which resources will be removed?
-   Under what conditions?
-   Why might automatic cleanup be useful?

Apply the policy.

``` bash
kubectl apply -f cleanup.yaml
kubectl apply -f job.yaml
```

Watch the Job.

``` bash
kubectl get jobs -w
```

## Points to Observe

-   When did the Job complete?
-   When was it deleted?
-   How might this help keep a cluster tidy?

### Enterprise Note

Cleanup policies reduce administrative effort and prevent obsolete
resources from accumulating in long-running clusters.

Clean up.

``` bash
kubectl delete cleanuppolicy delete-completed-jobs
```

------------------------------------------------------------------------

# Summary

You have successfully explored the four common Kyverno policy types.

  Policy Type   Primary Purpose
  ------------- -------------------------------------------
  Validate      Reject non-compliant resources
  Mutate        Modify resources during admission
  Generate      Automatically create supporting resources
  Cleanup       Remove obsolete resources

## Final Discussion

Discuss the following with your instructor.

-   Which policy would you deploy first in your organisation?
-   Which policy would provide the greatest operational benefit?
-   Which policies should begin in Audit mode?
-   How does Kyverno complement RBAC, Pod Security Admission and Network
    Policies?
