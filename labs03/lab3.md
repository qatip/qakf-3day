# Lab 3 - Volumes and Data
## 3.1 Volume mounts

### Task 1 - explore emptyDirs

1. Create a pod manifest using the `abhirockzz/kvstore` image use the `dry-run` and `-o yaml` technique to create a file called `lab3kv.yaml`. This is an image that runs a simple key/value store that uses the file system to store values.

<details><summary>show command</summary>
<p>

```bash
kubectl run kvstore --image=abhirockzz/kvstore --dry-run=client -o yaml > lab3kv.yaml
```

</p>
</details>
<br/>

2. Apply the YAMLfest and then find the new pod's IP address.

<details><summary>show command</summary>
<p>

```bash
kubectl apply -f lab3kv.yaml
kubectl get pod -o wide
```

</p>
</details>
<br/>

Example output:

```bash
pod/kvstore created

NAME  READY  STATUS   RESTARTS   AGE     IP               NODE
test  1/1    Running  0          22m     192.168.230.21   k8s-worker-1
```

<br/>

3. Try to put some data into the store. It will fail.

```bash
 curl 192.168.230.21:8080/save -d 'name=Nefertiti'
```

Example output:

```
Failed to create file /data/name due to --- open /data/name: no such file or directory
```

<br/>

4. We need to ensure that the `/data` directory exists. Start by deleting the existing pod.

<details><summary>show command</summary>
<p>

```bash
kubectl delete pod kvstore
```

</p>
</details>
<br/>

5. Modify the pod specification in the YAMLfest so that it adds a `volume` named `data-volume` of the `emptyDir` type and adds a `volumeMount` to the container definition that mounts `data-volume` at `/data`

lab3kv.yaml:

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: kvstore
  name: kvstore
spec:
  containers:
  - image: abhirockzz/kvstore
    name: kvstore
# ------ Add these lines ------
    volumeMounts:
    - mountPath: /data
      name: data-volume
  volumes:
  - name: data-volume
    emptyDir: {}
# -----------------------------
```

6. Apply the YAMLfest again and find out the new pod's IP address.

<details><summary>show command</summary>
<p>

```bash
kubectl apply -f lab3kv.yaml
kubectl get pod -o wide
```

</p>
</details>
<br/>

Example output:

```
pod/kvstore created

NAME  READY  STATUS   RESTARTS   AGE     IP               NODE
test  1/1    Running  0          22m     192.168.230.22   k8s-worker-1
```

<br/>

7. Retry adding data to the store. Make sure you're curling your pod's IP address.

```bash
 curl 192.168.230.22:8080/save -d 'name=Nefertiti'
```

Example output:

```
Saved value Nefertiti to /data/name
```

<br/>

8. Feel free to add more key/value pairs and then try reading the data.

```bash
 curl 192.168.230.22:8080/read/name
```

Example output:

```
Nefertiti
```

<details><summary>Stretch goal - optional exercise</summary>
<p>

9. **OPTIONAL stretch goal** see if you can find the emptyDir in your hosts' file system. It will involve finding out which node the pod is running on, connecting to that node and working out where in the file system the emptyDir is (you might be able to `find` a file named `data-volume`). Once you have found it, you could look for the files therein. Also, if you do take on this chalenge, observe, once you've deleted the pod, that the directory is removed.

</p>
</details>
<br/>

10. Delete the pod.

## 1.2 ConfigMaps

### Task 2 - create a ConfigMap from your index.html file

11. Create a deployment YAMLfest named `lab3web`, using the `httpd` image with 3 replicas, in a file named `lab3web.yaml`

<details><summary>show command</summary>
<p>

```bash
kubectl create deployment lab3web --image=httpd --replicas=3 --dry-run=client -o yaml > lab3web.yaml
```

</p>
</details>
<br/>

12. `Apply` the YAMLfest and `expose` it as a service on port 80.

<details><summary>show command</summary>
<p>

```bash
kubectl apply -f lab3web.yaml && kubectl expose deployment lab3web --port=80
```

</p>
</details>
<br/>

13. Find out the `ClusterIP` of the new service and **cURL** it.

<details><summary>show command</summary>
<p>

```bash
kubectl get service lab3web
curl ip-from-previous-command
```

</p>
</details>
<br/>

Example output:

```
NAME         TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
lab3web      ClusterIP   10.43.137.86   <none>        80/TCP           5s

curl 10.43.137.86
```

<br/>

Example output:

```
<html><body><h1>It works!</h1></body></html>
```

<br/>

14. Now create a file named `index.html` in your home directory. Its contents should be similar to the following, but feel free to customise the "welcome" message to suit yourself:

```html
<html><body><h1>Welcome to my home page!</h1></body></html>'
```

<details><summary>show command</summary>
<p>

```bash
echo '<html><body><h1>Welcome to my home page!</h1></body></html>' > ~/index.html
```

</p>
</details>
<br/>

15. Delete the deployment (but not the service).

16. Create a ConfigMap from the `index.html` file.

<details><summary>show command</summary>
<p>

```bash
kubectl create configmap homepage --from-file ~/index.html
```

</p>
</details>
<br/>

17. Edit (a copy of) the lab3web.yaml file to add a `configMap` volume, using the newly-created `homepage` configmap. Add a `volumeMount` to the container with a `mountPath` of `/usr/local/apache2/htdocs`. [NOTE: We could add additional files to the configmap and they'd be mounted in the same directory]

<details><summary>show YAML</summary>
<p>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: lab3web
  name: lab3web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: lab3web
  template:
    metadata:
      labels:
        app: lab3web
    spec:
      containers:
      - image: httpd
        name: httpd
# ------ Add these lines ------
        volumeMounts:
        - name: homepage
          mountPath: /usr/local/apache2/htdocs
      volumes:
      - name: homepage
        configMap:
          name: homepage
# -----------------------------
```

</p>
</details>
<br/>

18. Delete and then recreate the `lab3web` deployment.

<details><summary>show command</summary>
<p>

```bash
kubectl delete deployment lab3web
kubectl create -f lab3webconfigmap.yaml # whatever your edited file is called
```

</p>
</details>
<br/>

19. And **cURL** your lab3web service IP address again.

<details><summary>show command</summary>
<p>

```bash
 curl 10.101.251.165
```

</p>
</details>
<br/>

Example output:

```bash
<html><body><h1>Welcome to my home page ConfigMap!</h1></body></html>
```

<br/>

### Task 3 - modify the simple frontend deployment to use configmaps in environment variables

The simple frontend application also has a placeholder for a `COLOUR` environment variable. We're going to add different values for that in our different namespaces. 

20. Create a ConfigMap in both the development and production namespaces. Name the configmap `settings` and create a `colour` setting from a literal value with different values in each namespace. Purple and green are good choices, but feel free to use other values.

<details><summary>show command</summary>
<p>

```bash
kubectl create configmap settings --from-literal=colour=purple --namespace development
kubectl create configmap settings --from-literal=colour=green --namespace production
```

</p>
</details>
<br/>

21. Edit (a copy of) the lab2frontend.yaml file to add another `env` setting named `COLOUR` that gets its value from a `configMapKeyRef` with a `name` of `settings` and a `key` of `colour`. Maybe also find and replace all the `lab2frontend`s with `lab3frontend`s.

<details><summary>show YAML</summary>
<p>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: lab3frontend
  name: lab3frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: lab3frontend
  template:
    metadata:
      labels:
        app: lab3frontend
    spec:
      containers:
      - image: public.ecr.aws/qa-wfl/qa-wfl/qakf/sfe:v1
        name: sfe
        env:
# ------ Add these lines ------        
        - name: COLOUR
          valueFrom:
            configMapKeyRef:
              name: settings
              key: colour
# -----------------------------  
        - name: NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
```

</p>
</details>
<br/>

22. Create a sfe deployment in both the production and development namespaces. You did this in the second lab.

<details><summary>show commands</summary>
<p>

```bash
kubectl apply -f lab3frontend.yaml --namespace development
kubectl apply -f lab3frontend.yaml -n production
```

</p>
</details>
<br/>

23. Create a NodePort service exposing the deployment in both namespaces. Remember that the application is running on port 8080.

<details><summary>show command</summary>
<p>

```bash
kubectl expose deployment lab3frontend --port 8080 --type NodePort --namespace production 
kubectl expose deployment lab3frontend --port 8080 --type NodePort -n development
```

</p>
</details>
<br/>

24. Obtain the nodeport of both services and then browse to them.

<details><summary>show command</summary>
<p>

```bash
kubectl get service lab3frontend --all-namespaces
```

</p>
</details>
<br/>

<details><summary>Stretch goal - optional exercise</summary>
<p>

25. **OPTIONAL Stretch goal** also create the configmap in the test namespace and create and expose the frontend deployment therein.

</p>
</details>
<br/>

## 1.3 Secrets

### Task 4 - work with secrets

26. Create a `secret` called `secrets` from a literal value with a key of `password` in the dev and prod namespaces, with different values for each password.

<details><summary>show command</summary>
<p>

```bash
kubectl create secret generic secrets --from-literal password=MySecretPhrase --namespace development
kubectl create secret generic secrets --from-literal password=ReallySecret --namespace production
```

</p>
</details>
<br/>

27. Edit (a copy of) the lab3frontend.yaml file to add a `volume` to the deployment with a `name` of `secret-volume` and a `type` of `secret`, referencing your newly-created `secret`. Add a `volumeMount` to the container that mounts your secret at `/data`

<details><summary>show YAML</summary>
<p>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: lab3frontend
  name: lab3frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: lab3frontend
  template:
    metadata:
      labels:
        app: lab3frontend
    spec:
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
# ------ Add these lines ------
        volumeMounts:
        - name: secret-volume
          mountPath: /data
      volumes:
      - name: secret-volume
        secret:
          secretName: secrets
# -----------------------------
```

</p>
</details>
<br/>

28. Obtain the nodeport of both services and then browse to them.

<details><summary>show command</summary>
<p>

```bash
kubectl get service --all-namespaces
```

</p>
</details>
<br/>

<details><summary>Stretch goal - optional exercise</summary>
<p>

29. **Optional stretch goal** add the secret to the `test` namespace as well, then create and expose the frontend deployment therein.

</p>
</details>
<br/>

30. Tidy up. Delete all three deployments and the three services.

<details><summary>show command</summary>
<p>

```bash
kubectl delete deploy lab3frontend -n production
kubectl delete deploy lab3frontend -n development
kubectl delete service lab3frontend -n production
kubectl delete service lab3frontend -n development
kubectl delete deploy lab3web
kubectl delete service lab3web
```

</p>
</details>
<br/>

31. That's it, you're done! Let your instructor know that you've finished the lab.