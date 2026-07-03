# Lab 6c - Kyverno deeper dive

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




29. Create a new policy which requires all pods have a non-empty label "app.kubernetes.io/name"

<details>
<summary>Show policy YAML</summary>
<p>
    
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: pod-require-name-label
spec:
  validationFailureAction: Enforce
  background: true
  rules:
  - name: check-for-name-label
    match:
      any:
      - resources:
          kinds:
          - Pod
    exclude:
      any:
      - resources:
          namespaces:
          - kube-system
          - kyverno
    validate:
      message: "label 'app.kubernetes.io/name' is required"
      pattern:
        metadata:
          labels:
            app.kubernetes.io/name: "?*"
```

</p>
</details>

<details>
<summary>Show command</summary>
<p>

```bash
kubectl apply -f pod-name-policy.yaml
```

</p>
</details>

30. Attempt to create a pod which violates this policy:

<details>
<summary>Show command</summary>
<p>
    
```bash
kubectl run nginx --image=nginx:alpine
```

</p>
</details>

31. Observe that the pod is rejected as it violates the policy. Create the pod with the required label:

<details>
<summary>Show command</summary>
<p>

```bash
kubectl run nginx --image=nginx:alpine -l app.kubernetes.io/name=nginx
```

</p>
</details>

<details>
<summary>Stretch goal</summary>
<p>
    
32. Based on the example we have just seen, attempt to create a second policy which requires that all Pods have a security context with the following attributes:
    - `runAsNonRoot`: `true`
    - `runAsUser`: `any value greater than 1000`  

and are based on an image from the `public.ecr.aws/qa-wfl/qa-wfl/qakf` registry. Hint: you can use the Kyverno playground at https://playground.kyverno.io/ to dynamically experiment with policy configurations.

</p>
</details>