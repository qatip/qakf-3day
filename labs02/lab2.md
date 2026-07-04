# Lab 2 - Kubernetes Basics
## 2.1 - Working with Labels

### Task 1 - Confuse a ReplicaSet

1. Create a replicaset reusing the rs.yaml manifest from the previous lab:

rs.yaml:
```yaml
apiVersion: apps/v1 
kind: ReplicaSet 
metadata: 
  name: hello 
  labels: 
    app: hello 
spec: 
  replicas: 3 
  selector: 
    matchLabels: 
      app: hello 
  template: 
    metadata: 
      labels: 
        app: hello 
    spec: 
      containers: 
      - name: hello-world 
        image: public.ecr.aws/qa-wfl/qa-wfl/qakf/sbe:v1
```

```bash
kubectl create -f rs.yaml
```

2. Get a list of all the pods

```bash
kubectl get pods
```

Example output: 
```
NAME          READY   STATUS    RESTARTS   AGE
hello-5s5pd   1/1     Running   0          104s
hello-qbqsm   1/1     Running   0          104s
hello-s6k9l   1/1     Running   0          104s
```

3. Now let us confuse the ReplicaSet controller. We’ll manually modify the label of one of our pods so it no longer matches the selector: 

<details><summary>show command</summary>
<p>

```bash
kubectl edit pod hello-5s5pd 
```

</p>
</details>
<br/>

The default editor is vim, but that’s OK, we’re not doing much with it! 

Use the cursor keys to line up on the `app: hello` label near the top of the file. 

4. Press the `<i>` key to enter **INSERT** mode and change the value from “hello” to “hello1”. 

5. Hit `<esc>` to go back to command mode, type a colon (“:”) and then type “x” (for eXit and save) and hit `<enter>`.

6. List your pods and ReplicaSets again.

```bash
kubectl get pod,rs
```

Example output: 
```
NAME          READY   STATUS    RESTARTS   AGE
hello-45f6t   1/1     Running   0          39s
hello-5s5pd   1/1     Running   0          104s
hello-qbqsm   1/1     Running   0          104s
hello-s6k9l   1/1     Running   0          104s
```

You should now have 4! All named hello-something. The ReplicaSet controller noticed that there were only 2 pods with the correct label, so it initiated the creation of a new pod.

7. List pods again, but this time ask kubernetes to show you their labels: 

```bash
kubectl get pods --show-labels 
```

Example output: 
```
NAME          READY   STATUS    RESTARTS   AGE    LABELS 
hello-45f6t   1/1     Running   0          39s    app=hello 
hello-5s5pd   1/1     Running   0          104s   app=hello1 
hello-qbqsm   1/1     Running   0          104s   app=hello 
hello-s6k9l   1/1     Running   0          104s   app=hello 
```

8. Delete the replicaset

```bash
kubectl delete rs hello
```

9. And get the pods again (your output might be different, depending on quickly you type!)

```bash
kubectl get pods
```

Example output: 
```
NAME          READY   STATUS    RESTARTS   AGE
hello-5s5pd   1/1     Running   0          207s
```

The re-labelled pod is no longer controlled by the replicaset, so when you deleted the ReplicaSet, the modified pod remained.

8. Delete the orphaned pod. 

```bash
kubectl delete pod hello-5s5pd
```

### Task 2 - Add custom labels

9. Create a YAMLfest for a deployment that will use the httpd image.

```bash
kubectl create deploy lab02first --image=httpd --replicas=3 --dry-run=client -o yaml > lab02-first-dep.yaml
```

10. Edit the YAMLfest so that the pod template adds a label named "owner" with a value of *your name*.


<details><summary>show YAML</summary>
<p>

lab2dep.yml:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: lab2
  name: lab2
spec:
  replicas: 3
  selector:
    matchLabels:
      app: lab2
  template:
    metadata:
      labels:
        app: lab2
        owner: michaelcg  #<<<<<<<<<<<< ADD THIS LINE
    spec:
      containers:
      - image: httpd
        name: httpd
```

</p>
</details>
<br/>

11. Create another deployment with a different name, this time using an nginx image.

```bash
kubectl create deploy lab02second --image=nginx --replicas=3 --dry-run=client -o yaml > lab02-second-dep.yaml
```

12. And once more, edit the yaml and give the pod template an owner label with a value of *your name*. (Ensure you enter the same name)

lab2dep2.yml:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: hello
  name: hello
spec:
  replicas: 3
  selector:
    matchLabels:
      app: hello
  template:
    metadata:
      labels:
        app: hello
        owner: michaelcg #<<<<<<<<<<<< ADD THIS LINE
    spec:
      containers:
      - image: public.ecr.aws/qa-wfl/qa-wfl/qakf/sbe:v2
        name: sbe
```

13. Create both deployments.

```bash
kubectl create -f lab02-first-dep.yaml
kubectl create -f lab02-second-dep.yaml
```

14. Now list all of the pods using either the `--selector` switch or the shorthand `-l` switch to find all the pods that you own.

```bash
kubectl get pods --selector=owner=michaelcg
# or
kubectl get pods -l owner=michaelcg
```

15. Delete both deployments.

```bash
kubectl delete -f lab02-first-dep.yaml
kubectl delete -f lab02-second-dep.yaml
```


## 2.2 - Updating and rolling back deployments

### Task 3

16. Create a deployment using `v1` of the *simple backend* image (`public.ecr.aws/qa-wfl/qa-wfl/qakf/sbe`). Give it 5 replicas.

<details><summary>show command</summary>
<p>

```bash
kubectl create deploy lab2backend --image=public.ecr.aws/qa-wfl/qa-wfl/qakf/sbe:v1 --replicas=5
```

</p>
</details>
<br/>

17. Using the `kubectl set image` command, change the deployment to use v2 of the backend image. Immediately execute the `kubectl rollout pause` command.

<details><summary>show command</summary>
<p>

```bash
kubectl set image deployments/lab2backend \
    sbe=public.ecr.aws/qa-wfl/qa-wfl/qakf/sbe:v2 \
    && kubectl rollout pause deployments/lab2backend
```

</p>
</details>
<br/>

18. List your pods, replicasets and deployments. Ask for the output in wide format to see more information

<details><summary>show command</summary>
<p>

```bash
kubectl get pod,rs,deploy --output wide
```

</p>
</details>
<br/>

Example output (edited for clarity, and yours may vary depending on how quickly you type):

```bash
NAME                               READY   STATUS    RESTARTS        AGE
pod/lab2backend-7f8f47dd9c-xnz8r   1/1     Running   1 (2m30s ago)   6h8m
pod/lab2backend-7f8f47dd9c-7nsqj   1/1     Running   1 (2m30s ago)   7h8m
pod/lab2backend-7f8f47dd9c-vm78b   1/1     Running   1 (2m30s ago)   7h8m
pod/lab2backend-6c559d5b46-fz5vj   1/1     Running   1 (2m30s ago)   7h8m
pod/lab2backend-6c559d5b46-2gh7q   1/1     Running   1 (2m30s ago)   6h8m
pod/lab2backend-7f8f47dd9c-ctp86   1/1     Running   1 (2m30s ago)   6h8m
pod/lab2backend-6c559d5b46-9st7h   1/1     Running   1 (2m30s ago)   6h8m

NAME                                     DESIRED   CURRENT   READY   AGE     CONTAINERS   IMAGES
replicaset.apps/lab2backend-7f8f47dd9c   4         4         4       2d21h   sbe          public.ecr.aws/qa-wfl/qa-wfl/qakf/sbe:v1
replicaset.apps/lab2backend-6c559d5b46   3         3         3       2d21h   sbe          public.ecr.aws/qa-wfl/qa-wfl/qakf/sbe:v2

NAME                          READY   UP-TO-DATE   AVAILABLE   AGE     CONTAINERS   IMAGES
deployment.apps/lab2backend   7/5     3            7           2d21h   sbe          public.ecr.aws/qa-wfl/qa-wfl/qakf/sbe:v2
```

<br/>

Your deployment has 7 out of 5 pods in a `Ready` state. The default update settings for a deployment have a `maxSurge` value of 25% and a `maxUnavailable` of 25%. 25% of 5 is 1.25 but Kubernetes can't deal in fractions. So it's increased the size of the new v2 replicaset to 2 and decreased the size of the old v1 replicaset to 4 and then increased the size of the new replicaset to 3. Once that's settled down, it will continue cutting across to the new version until the size of the old replicaset is 0 and all 5 pods in the new replicaset are ready.

19. Resume the rollout of the new application version, immediately executing a Linux watch command to see the pods being rolled out.

<details><summary>show command</summary>
<p>

```bash
kubectl rollout resume deployments/lab2backend \
  && watch kubectl get pods,rs,deploy
```

</p>
</details>
<br/>

20. Press `<ctrl>+c` to end the watch when it's done.

21. Undo the rollout to revert back to version 1 of the application.

<details><summary>show command</summary>
<p>

```bash
kubectl rollout undo deployments/lab2backend
```

</p>
</details>
<br/>

## 2.3 - Working with Namespaces

22. Create two new namespaces: `development` and `production`. Feel free to abbreviate to `dev` and `prod` if you wish.

<details><summary>show command</summary>
<p>

```bash
kubectl create namespace development
kubectl create ns production
```

</p>
</details>
<br/>

23. Now create a YAMLfest for a deployment of the `public.ecr.aws/qa-wfl/qa-wfl/qakf/sfe:v1` image. Name the deployment `lab2frontend`.

<details><summary>show command</summary>
<p>

```bash
kubectl create deployment lab2frontend --image=public.ecr.aws/qa-wfl/qa-wfl/qakf/sfe:v1 \
  --dry-run=client -o yaml > lab2frontend.yaml
```

</p>
</details>
<br/>

24. Edit the YAMLfest to add an env setting that picks up the pod's namespace from the pod's metadata. Our simple front-end (`sfe`) container image uses environment variables to collect some of the information it displays.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: lab2frontend
  name: lab2frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: lab2frontend
  template:
    metadata:
      labels:
        app: lab2frontend
    spec:
      containers:
      - image: public.ecr.aws/qa-wfl/qa-wfl/qakf/sfe:v1
        name: sfe
# ------ Add these lines ------
        env:
        - name: NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
# -----------------------------
        resources: {}
status: {}
```

25. Apply the manifest in both namespaces.

```bash
kubectl apply -f lab2frontend.yaml --namespace development
kubectl apply -f lab2frontend.yaml -n production
```
Verify pod creation in the namespaces:

```bash
kubectl get pods --namespace development
kubectl get pods -n production
```

26. Create a NodePort service exposing the deployment in both namespaces. The application is running on port 8080.

```bash
kubectl expose deployment lab2frontend --port 8080 --type NodePort --namespace production 
kubectl expose deployment lab2frontend --port 8080 --type NodePort -n development
```

27. Obtain the nodeport of both services and then browse to them.

```bash
kubectl get service --all-namespaces
```

In order to browse to them, you'll need your controller's IP address followed by the `:3xxxx` of your service's nodeport (at the far right of the output).

If you're using our Goto My PC environment, that will be:

```http://k8s-controller-0:3xxxx```

If you're using a cloud environment, use the following command to obtain your Public IP address:

```bash
curl ifconfig.io
```

And browse to:

```http://output-from-curl-command:3xxxx```


<details><summary>Stretch goals - optional exercises</summary>
<p>

28. **OPTIONAL Stretch goal 1** also create a test namespace and create and expose the frontend deployment therein.

29. **OPTIONAL Stretch goal 2** there are also placeholders for the pod name and the node name on the frontend image's homepage. See if you can get those values to display instead of *unknown*.  Adding the pod's name to the deployment's environment variables is very similar to how you added the namespace, but the node name might involve a bit of web searching. The image is expecting an environment variable named `POD_NAME` and another one named `NODE_NAME`.

</p>
</details>
<br/>

30. Tidy up. Delete all three deployments and the two services.

<details><summary>show command</summary>
<p>

```bash
kubectl delete deployment lab2backend
kubectl delete deploy lab2frontend -n production
kubectl delete deploy lab2frontend -n development
kubectl delete service lab2frontend -n production
kubectl delete service lab2frontend -n development
```

</p>
</details>
<br/>

31. That's it, you're done! Let your instructor know that you've finished the lab.