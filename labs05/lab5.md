# Lab 5 - DaemonSets, Jobs and Helm

## 5.1 DaemonSets

1. Look to see if there are any daemonsets running on the cluster. Look in all namespaces. Use --output=wide.

<details><summary>show command</summary>
<p>

```bash
kubectl get daemonsets --all-namespaces --output=wide
```

</p>
</details>
<br/>

Example output:

```
NAMESPACE     NAME         DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
kube-system   cilium       3         3         3       3            3           kubernetes.io/os=linux   24m
kube-system   kube-proxy   3         3         3       3            3           kubernetes.io/os=linux   24m
```

<br/>

2. Create a YAMLfest for a `DaemonSet` named `dsweb` using the `httpd` image. It's very similar to a deployment, but has a different `kind` and no `replicas` property.

<details><summary>show YAML</summary>
<p>

**ds.yaml**:
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: dsweb
spec:
  selector:
    matchLabels:
      app: dsweb
  template:
    metadata:
      labels:
        app: dsweb
    spec:
      containers:
      - image: httpd
        name: httpd
```

</p>
</details>
<br/>

3. Create the daemonset.

<details><summary>show command</summary>
<p>

```bash
kubectl create -f ds.yaml
```

</p>
</details>
<br/>

4. Expose it as a NodePort service and then browse to it. Intriguingly, the `kubectl expose` command returns an error for a daemonset, so we'll have to create the service via a YAMLfest.

<details><summary>show YAML</summary>
<p>

**ds_service.yaml**:
```yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: dsweb
  name: dsweb
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: dsweb # make sure this matches the labels of your daemonset's pods
  type: NodePort
```

</p>
</details>
<br/>

<details><summary>Stretch goal - optional exercise</summary>
<p>

5. **Optional stretch goal** if you `kubectl get` daemonsets in all namespaces you'll see that you only have two pods running whereas the system daemonsets both have 3. Can you work out why that is (and make it so yours works the same way). Hint: try describing the system ds pods, your ds pods and describing the nodes. This topic is not a part of this course.

</p>
</details>
<br/>

6. Delete the daemonset and the service.

<details><summary>show command</summary>
<p>

```bash
kubectl delete ds dsweb
kubectl delete svc dsweb
```

</p>
</details>
<br/>

## 5.2 Jobs

7. Create a YAMLfest for a `job` that prints a random number.

**job.yaml**:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: randoms
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: example
        image: python
        command:
        - python3
        - -c
        - |
          import random
          print(random.randrange(1,100))
```

8. Create the `job`.

<details><summary>show command</summary>
<p>

```bash
kubectl create -f job.yaml
```

</p>
</details>
<br/>

9. Watch the job until it has 1/1 completions. This might take a minute or so as Kubernetes will need to pull the image before it can run.

<details><summary>show command</summary>
<p>

```bash
kubectl get job --watch
```

</p>
</details>
<br/>

10. Once it's completed, get the pod's logs.

<details><summary>show command</summary>
<p>

```bash
kubectl get pods
kubectl logs randoms-t66kh # get the pod name from the output of the previous command
```

</p>
</details>
<br/>

11. Delete the job. Note that deleting the job will also delete its completed pod.

<details><summary>show command</summary>
<p>

```bash
kubectl delete -f job.yaml
```

</p>
</details>
<br/>

12. Change it to have 3 `completions`. The `completions` property is part of the job's spec, not the pod's.

<details><summary>show YAML</summary>
<p>

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: randoms
spec:
# ------ Add this line ------ 
  completions: 3
# ---------------------------
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: example
        image: python
        command:
        - python3
        - -c
        - |
          import random
          print(random.randrange(1,100))
```

</p>
</details>
<br/>

13. Create the job and then watch it until there are 3 completions.

<details><summary>show command</summary>
<p>

```bash
kubectl create -f job.yaml
kubectl get jobs -w
```

</p>
</details>
<br/>

14. Get all 3 pods' logs. You'll need to get the pods and then run `kubectl logs` once for each pod. Then delete the job again.

<details><summary>show command</summary>
<p>

```bash
kubectl get pods
kubectl logs randoms-66zm7
kubectl logs randoms-g8p4f
kubectl logs randoms-pnlvv
kubectl delete -f job.yaml
```

</p>
</details>
<br/>

15. Change it to 10 `completions`, `parallelism` 3.

<details><summary>show YAML</summary>
<p>

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: randoms
spec:
  completions: 10    # <== Change the 3 to a 10
# ------ Add this line ------ 
  parallelism: 3
# ---------------------------
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: example
        image: python
        command:
        - python3
        - -c
        - |
          import random
          print(random.randrange(1,100))
  completions: 10
```

</p>
</details>
<br/>

16. Create the job and immediately start watching jobs. Observe that they're running 3 at a time. Once the watch shows 10 completions, move on to the next step.

<details><summary>show command</summary>
<p>

```bash
kubectl create -f job.yaml && kubectl get jobs --watch
```

</p>
</details>
<br/>

17. Get all 10 pods' logs. You should know the drill by now... Wait a minute, surely there's an easier way than manually typing in all those pods' names? When a job creates a pod, it adds a label with its `job-name` to the pod, so we can generate a list of all the pods using the selector. And we're only interested in their names.

```bash
kubectl get pods --selector=job-name=randoms --output=name
```

So we can pass the result of that command into a bash `for` loop and get all 10 sets of logs.

<details><summary>show command</summary>
<p>

```bash
for pod in $(kubectl get pods -l=job-name=randoms -o name); do kubectl logs $pod; done
```

</p>
</details>
<br/>

18. Delete the job again.

## 5.3 CronJobs

19. Turn the Job into a CronJob that runs once a minute, with no completions or parallelism. The `CronJob`'s spec will have a jobTemplate, which will have your original job's spec, which will have a template with the pod's spec.

<details><summary>show YAML</summary>
<p>

**cronjob.yaml**:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: randoms
spec:
  schedule: "* * * * *"
  jobTemplate:
    metadata:
      name: randoms
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: example
            image: python
            command:
            - python3
            - -c
            - |
              import random
              print(random.randrange(1,100))
```

</p>
</details>
<br/>

20. Take a 10-minute break.

21. Check logs. We won't be able to use our clever bash script from earlier because the CronJob creates the jobs, which create the pods, so each `job-name` label is unique. Let's start by `get`ting all pods.

<details><summary>show command</summary>
<p>

```bash
kubectl get pods
```

</p>
</details>
<br/>

Example output:

```
NAME                       READY   STATUS      RESTARTS      AGE
randoms-28557293-ldn7r     0/1     Completed   0             2m50s
randoms-28557294-g577p     0/1     Completed   0             110s
randoms-28557295-vxvc8     0/1     Completed   0             50s
```

<br/>

What? There are only 3 pods! We left the cronjob running for 10 minutes, so surely there should be 10 pods, right?

22. A CronJob only retains some of its completed pods. There are some properties we can set for how many successful pods and how many failed pods to retain. To find out what the default values are, you could either `get` as yaml or `describe` the CronJob and look for the word "Limit".

<details><summary>show command</summary>
<p>

```bash
kubectl get cronjob randoms -o yaml | grep Limit
#or
kubectl describe cronjob randoms | grep Limit
```

</p>
</details>
<br/>

23. Delete the CronJob

## 5.4 Helm

24. Search artifact hub for httpd charts.

<details><summary>show command</summary>
<p>

```bash
helm search hub httpd
```

</p>
</details>
<br/>

25. It might be nice to see some more details. Try getting the output in YAML format.

<details><summary>show command</summary>
<p>

```bash
helm search hub httpd -o yaml
```

</p>
</details>
<br/>

26. Sadly, none of those are what we're after. Let's add the `https://charts.bitnami.com/bitnami` repo and call it `bitnami`.

<details><summary>show command</summary>
<p>

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
```

</p>
</details>
<br/>

27. Use helm to install apache from the bitnami repo with a name of "myweb".

<details><summary>show command</summary>
<p>

```bash
helm install myweb bitnami/apache
```

</p>
</details>
<br/>

28. Get the IP address / nodeport of the newly created service and browse to it.

<details><summary>show command</summary>
<p>

```bash
kubectl get services
```

</p>
</details>
<br/>

Example output:

```
NAME           TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
kubernetes     ClusterIP      10.96.0.1        <none>        443/TCP                      78d
myweb-apache   LoadBalancer   10.99.216.246    <pending>     80:30549/TCP,443:30471/TCP   3m2s
```

<br/>

Note that the service is named `myweb-apache`, which is a combination of the name of the release you installed and the name of the chart. Also note that it has created a LoadBalancer service, which we don't need in this cluster.

29. `Upgrade` the release, changing the `service.type` to `NodePort`.

<details><summary>show command</summary>
<p>

```bash
helm upgrade myweb bitnami/apache \
    --set service.type=NodePort
```

</p>
</details>
<br/>

30. Get the service again. Note that the service hasn't been deleted and recreated, just modified in-place. Anything that was pointing at `myweb` before is still pointing at the same thing.

<details><summary>show command</summary>
<p>

```bash
kubectl get service
```

</p>
</details>
<br/>

Example output:

```
NAME           TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
kubernetes     ClusterIP      10.96.0.1        <none>        443/TCP                      78d
myweb-apache   LoadBalancer   10.99.216.246    <none>        80:30549/TCP,443:30471/TCP   3m2s
```

<br/>

<details><summary>Stretch goal - optional exercise</summary>
<p>

31. **Optional stretch goal** create an ingress rule for `myweb` at web.yourip.nip.io. If you do this, you can change the release's service type to a ClusterIP instead of a NodePort.

</p>
</details>
<br/>

32. That's it, you're done! Let your instructor know that you've finished the lab.