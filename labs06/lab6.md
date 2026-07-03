# Lab 6 - Security
## 6.1 RBAC

We're going to create a pod that prints all of the logs of all of our randoms jobs.

1. Recreate the Job from the previous lab (with 10 completions). Give it a few moments to complete.

<details><summary>show command</summary>
<p>

```bash
kubectl create -f job.yaml # use the correct YAMLfest here
```

</p>
</details>
<br/>

2. Create a pod named `kubectl` using the `bitnami/kubectl` image. Give it a `command` property to `sleep infinity` like we did with the busybox pod in the networking lab to keep it from completing.

<details><summary>show command</summary>
<p>

```bash
kubectl run kubectl --image=bitnami/kubectl --command sleep infinity
```

</p>
</details>
<br/>

3. Now `exec -it` into the kubectl pod and run the command (with `sh -c`) that we came up with in the previous lab for getting all the pods' logs. It should fail.

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

```
Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:default:default" cannot list resource "pods" in API group "" in the namespace "default"
```

<br/>

The kubectl pod doesn't have permission to get pods or their logs!

4. Create a clusterrole named `pod-logger` that allows `get` and `list` verbs on resources `pods` and `pods/logs`. You can create a YAMLfest to do this and then `apply` it, **or** you can do it via the command line.

<details><summary>show kubectl command</summary>
<p>

```bash
kubectl create clusterrole pod-logger --verb=get,list --resource=pods,pods/log
```

</p>
</details>
<br/>

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

5. Create a rolebinding to bind the ClusterRole to the `default` service account in the `default` namespace. Again you have YAML or command line options.

<details><summary>show kubectl command</summary>
<p>

```bash
kubectl create rolebinding pod-logger-binding \
    --clusterrole=pod-logger --serviceaccount=default:default
```

</p>
</details>
<br/>

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
kubectl create -f rolebinding.yaml
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

## 6.2 Network Policies

7. **cURL** the frontend service and the backend service in each ns. You'll need to `get services` in both namespaces and then **cURL** their ClusterIP addresses.

<details><summary>show command</summary>
<p>

```bash
kubectl get service -n production
kubectl get service -n development
```

</p>
</details>
<br/>

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

13. Try **cURL**ing the backend service in production. It should now fail, but the frontend service should still be able to communicate with it.

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

<details><summary>Stretch goal - optional exercise</summary>
<p>

15. **Optional stretch goal** create the network policies in the test namespace as well.

</p>
</details>
<br/>

## 6.3 Pod Security

16. Create an httpd pod with a `securityContext` that sets `runAsNonRoot` to `true`.

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

17. Give it thirty seconds or so and then run `kubectl get pods`. You should see a `CreateContainerConfigError` and if you `describe` the pod, you'll see that the httpd image wants to run as root but you've said it can't.

<details><summary>Stretch goal - optional exercise</summary>
<p>

18. **Optional stretch goal** try to find a non-privileged httpd image and use that instead.

</p>
</details>
<br/>

19. Add a `runAsNonRoot`: `true` to your frontend deployments in `development` and `production` (and `test` if you have that namespace and feel like doing it). You will need to recreate the deployments. They should be fine, because they're both listening on port 8080 and Kubernetes can tell that they don't need to run as root.

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

<details><summary>Stretch goal - optional exercise</summary>
<p>

20. **Optional stretch goal** try the same thing with a backend deployment. The simple `runAsNonRoot` won't work in this case because Kubernetes can't tell from the container image that it doesn't need to run as root. Hint: try making it run as a specific user id.

</p>
</details>
<br/>


21. That's it, you're done! Let your instructor know that you've finished the lab.