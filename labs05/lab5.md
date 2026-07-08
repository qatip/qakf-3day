# Lab 5 - Security

## 5.1 RBAC

**Behind the Scenes – Service Accounts**

Every Kubernetes namespace automatically contains a ServiceAccount named **default**. Unless you explicitly specify a different service account in a Pod or Deployment manifest, Kubernetes assigns this default account to every Pod created in that namespace.

You can see it by running: **kubectl get serviceaccounts**

You can also confirm which ServiceAccount a Pod is using:

kubectl get pod {pod-name} -o jsonpath='{.spec.serviceAccountName}'

What permissions does the default ServiceAccount have?

Almost none.

Modern Kubernetes clusters follow the principle of least privilege, meaning the default ServiceAccount is not automatically granted permission to list Pods, read Secrets, retrieve logs, or modify cluster resources.

In this exercise you will:

Create a ClusterRole that allows Pods and Pod logs to be read.
Bind that role to the default ServiceAccount using a RoleBinding.

***Can I create additional ServiceAccounts?***

Absolutely — and in production environments you almost always should.

kubectl create serviceaccount logger

You can then tell a Pod or Deployment to use it:

spec:
  serviceAccountName: logger

This allows different applications to have different permissions. For example:

frontend → read ConfigMaps only
backup → read PersistentVolumes
monitoring → read Pod logs
deployment-controller → create and delete Pods

Giving every workload its own ServiceAccount is considered a Kubernetes security best practice because it follows the principle of least privilege.

We're going to start by creating and running a job manifest that creates 10 pods, each of which randomly generates a number. The aim eventually is to use another pod to look at the logs these 10 pods create (showing the number generated):

1. Create and examine **job.yaml** before applying it to create the 10 random number generator pods.

```bash
cd ~
cp ~/qakf-3day/solutions/lab5/job.yaml ./job.yaml
```

``` bash
kubectl apply -f job.yaml
```

2. Create a pod named `kubectl` using the `bitnami/kubectl` image. Give it a `command` property to `sleep infinity` like we did with the busybox pod in the networking lab to keep it from completing.

```bash
kubectl run kubectl --image=bitnami/kubectl --command sleep infinity
```
<br/>

3. Now `exec -it` into the kubectl pod and run a command that attempts to retrieve all the pods' logs. It should fail!

```bash
kubectl exec -it kubectl -- \
    sh -c 'for pod in $(kubectl get pods -l=job-name=randoms -o name); do kubectl logs $pod; done'
```
<br/>


Example output:

```
Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:default:default" cannot list resource "pods" in API group "" in the namespace "default"
```

The kubectl pod doesn't have permission to get pods or their logs!

The current user account you are using 'student' does have permissions to view logs directly though:

```
kubectl get pods -l job-name=randoms -o name | xargs -I{} kubectl logs {}
```

We need to create a cluster role and assign it to the service account used within the kubectl pod that allows it to retrieve logs.


4. Create manifest ***clusterrole.yaml*** and apply it to create a cluster role named `pod-logger` that allows `get` and `list` verbs on resources `pods` and `pods/logs`. 

<details><summary>show YAML</summary>
<p>

**clusterrole.yaml**:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-logger
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list"]
```

```bash
kubectl create -f clusterrole.yaml
```

</p>
</details>
<br/>

5. Create and apply a rolebinding manifest to bind the ClusterRole to the `default` service account in the `default` namespace. 

<details><summary>show YAML</summary>
<p>

**rolebinding.yaml**:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-logger-binding
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: pod-logger
subjects:
- kind: ServiceAccount
  name: default
  namespace: default
```

```bash
kubectl apply -f rolebinding.yaml
```

</p>
</details>
<br/>

6. Try the `kubectl exec` command from step 3 again.

<details><summary>show command</summary>
<p>

```bash
kubectl exec -it kubectl -- \
    sh -c 'for pod in $(kubectl get pods -l=job-name=randoms -o name); do kubectl logs $pod; done'
```

</p>
</details>
<br/>

Example output:

```bash
79
89
50
58
63
40
17
53
96
28
```

<br/>

## 5.2 Network Policies

7. **cURL** the frontend service and the backend service in each ns. You'll need to `get services` in both namespaces and then **cURL** their ClusterIP addresses.

```bash
kubectl get service -n production
kubectl get service -n development
```

Example output:

```
NAME       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
backend    ClusterIP   10.105.142.21   <none>        80/TCP    5d18h
frontend   ClusterIP   10.99.254.121   <none>        80/TCP    5d17h

NAME       TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
backend    ClusterIP   10.102.60.108    <none>        80/TCP    5d18h
frontend   ClusterIP   10.104.176.195   <none>        80/TCP    5d17h
```

<br/>

***note***
If you have not completed lab4 in this current session then you will get error messages stating 'No resources found ....'

Run the following commands to reinstate assumed namespace/deployments/services/configmaps/secrets resources...

<details><summary>show command</summary>
<p>

```bash
kubectl create namespace development || true
kubectl create namespace production || true
kubectl create configmap settings --from-literal=colour=purple --namespace development || true
kubectl create configmap settings --from-literal=colour=green --namespace production || true
kubectl create secret generic secrets --from-literal password=DevSecret --namespace development || true
kubectl create secret generic secrets --from-literal password=ProdSecret --namespace production || true

kubectl create deploy backend --image=public.ecr.aws/qa-wfl/qa-wfl/qakf/sbe:v1 -n production 
kubectl create deploy backend --image=public.ecr.aws/qa-wfl/qa-wfl/qakf/sbe:v2 -n development
kubectl expose deployment backend --port 80 --target-port 8080 --name backend -n production 
kubectl expose deployment backend --port 80 --target-port 8080 --name backend -n development

kubectl apply -n production -f ./qakf-3day/solutions/lab4/lab4frontend.yaml
kubectl apply -n development -f ./qakf-3day/solutions/lab4/lab4frontend.yaml
kubectl expose deployment frontend --port 80 --target-port 8080 --name frontend -n production 
kubectl expose deployment frontend --port 80 --target-port 8080 --name frontend -n development

kubectl get service -n production
kubectl get service -n development
```

</p>
</details>
<br/>

8. Create a netpol that allows all traffic on port 8080 to pods with an `app` label with a value of `frontend`. But check that your pods actually have a `label` of `frontend` and not `lab3frontend` or `lab4frontend`. If they do, you may need to tweak things. Either modify the deployment manifest and recreate it, or modify the pod selector in the netpol.

<details><summary>show command</summary>
<p>

**netpol_frontend.yaml**:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-8080-to-frontend
spec:
  podSelector:
    matchLabels:
      app: frontend # ensure that this matches your pods' actual labels.
  ingress:
  - ports:
    - port: 8080
```

</p>
</details>
<br/>

9. Apply it in both namespaces.

<details><summary>show command</summary>
<p>

```bash
kubectl apply -f netpol_frontend.yaml -n production
kubectl apply -f netpol_frontend.yaml -n development
```

</p>
</details>
<br/>

10. Again, curl the frontend service in each namespace. It should still work because we're allowing all traffic into those pods. You should also be able to test via the browser if your ingress controller is still working.

11. Create another netpol that allows traffic to pods with an `app` label with a value of `backend` from pods with an `app` label of `frontend` from a namespace with a `kubernetes.io/metadata.name` label of `production`. Once again, you should check what the actual labels are for your frontend and backend pods.

<details><summary>show command</summary>
<p>

**netpol_backend_prod.yaml**:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-8080-from-frontend
  namespace: production           # explicit namespace
spec:
  podSelector:
    matchLabels:
      app: backend            # ensure this matches your pods' labels
  ingress:
  - from:
      - podSelector:
          matchLabels:
            app: frontend         # ensure this matches your pods' labels
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: production
    ports:                        # unlike previous netpol, this is part of the "from" rule
    - port: 8080
```

</p>
</details>
<br/>

12. Apply it to the `production` namespace.

<details><summary>show command</summary>
<p>

```bash
kubectl apply -f netpol_backend_prod.yaml
```

</p>
</details>
<br/>

13. Try **cURL**ing directly to the backend service in production. It should now fail, but the frontend service should still be able to communicate with it.

<details><summary>show command</summary>
<p>

```bash
curl --max-time 10 \
    $(kubectl get svc backend -n production --no-headers -o=custom-columns=ip:.spec.clusterIP)
```

</p>
</details>
<br/>

14. Repeat the previous three steps for the `development` namespace.

<details><summary>show YAML</summary>
<p>

**netpol_backend_dev.yaml**:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-8080-from-frontend
  namespace: development
spec:
  podSelector:
    matchLabels:
      app: backend
  ingress:
  - from:
      - podSelector:
          matchLabels:
            app: frontend
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: development
    ports:
    - port: 8080
```

</p>
</details>
<br/>


## 5.3 Pod Security

15. Create an httpd pod with a `securityContext` that sets `runAsNonRoot` to `true`.

<details><summary>show command</summary>
<p>

```bash
kubectl run web \
  --image=httpd \
  --overrides='{ "spec": { "securityContext": {"runAsNonRoot": true} }  }'
```

</p>
</details>
<br/>

16. Give it thirty seconds or so and then run `kubectl get pods`. You should see a `CreateContainerConfigError` and if you `describe` the pod, you'll see that the httpd image wants to run as root but you've said it can't. Delete the failed pod:

```bash
kubectl delete pod web
```

17. **Stretch goal.** 
Try to find a non-privileged httpd image and use that instead.

The official httpd image expects to run as the root user, so it cannot be used with runAsNonRoot: true.

Your challenge is to research and identify an Apache HTTP Server container image that is designed to run as a non-root user.

Once you've found one:

Deploy it using kubectl run.

Configure the Pod with:

securityContext:
  runAsNonRoot: true

Verify that the Pod reaches the Running state.

Use kubectl describe pod to confirm there are no security context errors.

Hint: Images published by organisations such as Bitnami are often built to run as an unprivileged user by default.


18. **Optional** Add a `runAsNonRoot`: `true` to your frontend deployments in `development` and `production` (and `test` if you have that namespace and feel like doing it). You will need to recreate the deployments. They should be fine, because they're both listening on port 8080 and Kubernetes can tell that they don't need to run as root.

<details><summary>show YAML</summary>
<p>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: frontend
  name: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
# ------ Add these lines ------
      securityContext:
        runAsNonRoot: true
# -----------------------------
      containers:
      - image: public.ecr.aws/qa-wfl/qa-wfl/qakf/sfe:v1
        name: sfe
        env:
        - name: COLOUR
          valueFrom:
            configMapKeyRef:
              name: settings
              key: colour        
        - name: NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        volumeMounts:
        - name: secret-volume
          mountPath: /data
      volumes:
      - name: secret-volume
        secret:
          secretName: secrets
```

</p>
</details>
<br/>

19. Clean up ahead of the next lab:

```bash
kubectl delete namespace production
kubectl delete namespace development
kubectl delete namespace ingress-nginx
kubectl delete jobs randoms
kubectl delete rolebindings pod-logger-binding
kubectl delete clusterrole pod-logger
kubectl delete pod kubectl
kubectl delete pod web
kubectl delete ingressclasses nginx 
```

20. That's it, you're done! Let your instructor know that you've finished the lab.