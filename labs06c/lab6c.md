# Lab 6c - Policy as Code with Kyverno deeper look

## Objectives

In this lab you will explore the four common Kyverno policy types:

-   **Validate** -- Reject non-compliant resources
-   **Mutate** -- Automatically modify resources
-   **Generate** -- Automatically create related resources
-   **Cleanup** -- Automatically remove resources that are no longer
    required

**Estimated time:** 45--60 minutes

------------------------------------------------------------------------

# 6c.1 Validate Policies

## Objective

Prevent developers from deploying container images using the `latest`
tag.

Create **validate.yaml**:

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

Apply the policy:

``` bash
kubectl apply -f validate.yaml
```

Attempt a deployment:

``` bash
kubectl create deployment bad --image=nginx:latest
```

Observe that the deployment is rejected.

Now deploy a versioned image:

``` bash
kubectl create deployment good --image=nginx:1.28.1
```

Verify:

``` bash
kubectl get deployment
kubectl get pods
```

Remove the policy:

``` bash
kubectl delete clusterpolicy validate-images
```

------------------------------------------------------------------------

# 6c.2 Mutate Policies

## Objective

Automatically add a label to every Deployment.

Create **mutate.yaml**:

``` yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-managed-label
spec:
  rules:
  - name: add-label
    match:
      any:
      - resources:
          kinds:
          - Deployment
    mutate:
      patchStrategicMerge:
        metadata:
          labels:
            managed-by: kyverno
```

Apply the policy:

``` bash
kubectl apply -f mutate.yaml
```

Create a deployment:

``` bash
kubectl create deployment web --image=nginx:1.28.1
```

Inspect it:

``` bash
kubectl get deployment web -o yaml
```

Notice the automatically-added label.

Cleanup:

``` bash
kubectl delete deployment web
kubectl delete clusterpolicy add-managed-label
```

------------------------------------------------------------------------

# 6c.3 Generate Policies

## Objective

Automatically create a ConfigMap whenever a Namespace is created.

Create **generate.yaml**:

``` yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: namespace-default-config
spec:
  rules:
  - name: generate-config
    match:
      any:
      - resources:
          kinds:
          - Namespace
    generate:
      kind: ConfigMap
      apiVersion: v1
      name: default-config
      namespace: "{{request.object.metadata.name}}"
      synchronize: true
      data:
        data:
          environment: training
```

Apply the policy:

``` bash
kubectl apply -f generate.yaml
```

Create a namespace:

``` bash
kubectl create namespace finance
```

Verify:

``` bash
kubectl get configmap -n finance
kubectl describe configmap default-config -n finance
```

Cleanup:

``` bash
kubectl delete namespace finance
kubectl delete clusterpolicy namespace-default-config
```

------------------------------------------------------------------------

# 6c.4 Cleanup Policies

## Objective

Automatically remove completed Jobs.

Create **cleanup.yaml**:

``` yaml
apiVersion: kyverno.io/v2beta1
kind: CleanupPolicy
metadata:
  name: delete-completed-jobs
spec:
  schedule: "*/1 * * * *"
  match:
    any:
    - resources:
        kinds:
        - Job
  conditions:
    any:
    - key: "{{ target.status.succeeded }}"
      operator: Equals
      value: 1
```

Apply the policy:

``` bash
kubectl apply -f cleanup.yaml
```

Create a simple Job:

``` yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: cleanup-demo
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: hello
        image: busybox
        command: ["echo","Hello Kyverno"]
```

Apply the Job:

``` bash
kubectl apply -f job.yaml
```

Watch it complete:

``` bash
kubectl get jobs -w
```

Observe the completed Job being removed automatically.

Cleanup:

``` bash
kubectl delete cleanuppolicy delete-completed-jobs
```

------------------------------------------------------------------------

# Review

  Policy Type   Purpose
  ------------- -----------------------------------------
  Validate      Reject non-compliant resources
  Mutate        Modify resources before they are stored
  Generate      Create related resources automatically
  Cleanup       Remove obsolete resources

## Discussion

-   Which policy type would be most useful in your organisation?
-   Which policies should be enforced immediately?
-   Which should begin in Audit mode before being enforced?
-   How does Kyverno complement RBAC and Pod Security Admission?
