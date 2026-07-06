# Lab 6a - Policy and Governance

## 6a.1 Setup the Namespaces

1. Create and label the two namespaces we will be using for this lab and ensure no remnants from previous labs remain that might cause issues:

```bash
kubectl create ns webserver
kubectl create ns ingress
kubectl label ns webserver app=webserver
kubectl label ns ingress app=nginx-ingress
kubectl delete ingress
```

2. Apply a Pod Security Standard of `Restricted` to the webserver namespace:

```bash
kubectl label ns webserver pod-security.kubernetes.io/enforce=restricted
```

3. Generate a manifest for a `ResourceQuota` object and apply it to the webserver namespace:

```bash
kubectl create quota webserver-quota --hard=pods=5,cpu=2,memory=2G --dry-run=client -o yaml > ws-quota.yml
kubectl apply -n webserver -f ws-quota.yml
```

4. Review the provided `NetworkPolicy` resource manifest for the webserver namespace (`nano ~/qakf-3day/solutions/lab6a/netpol_webserver.yaml`). Fill in the `from` and `ports` sections to allow traffic from the ingress namespace on port 8080. See the solution below if needed

<details>
<summary>solution</summary>

```yaml
# rest of yaml omitted
ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          app: nginx-ingress 
    ports:
    - protocol: TCP
      port: 8080
# rest of yaml omitted
```

</details>

5. Apply the `NetworkPolicy` resources for the two namespaces:

```bash
kubectl -n ingress apply -f solutions/lab6a/netpol_ingress.yaml
kubectl -n webserver apply -f solutions/lab6a/netpol_webserver.yaml
```

6. Use helm to deploy the Nginx ingress controller into the ingress namespace:

```bash
helm -n ingress install nginx-ingress oci://ghcr.io/nginx/charts/nginx-ingress --version 2.5.2 --set controller.kind=daemonset
```

## 6a.2 Deploy the Webserver

7. Generate a deployment manifest using `kubectl create`:

```bash
kubectl create deploy webserver --replicas=10 --image=nginx:alpine --port=80 --dry-run=client -o yaml > deploy.yml
```

8. Apply the manifest:

```bash
kubectl apply -n webserver -f deploy.yml
```
You will notice that, although the deployment is created, we get a warning about a policy violation. Confirm that there are currently no pods:

```bash
kubectl -n webserver get pods
```

9. We don't need to look too hard to see what the problem could be here, thanks to the warning we got when creating the deployment. Our restricted pod security standard requires certain privilege limitations which are not currently present on our pods. 

10. Add an appropriate securityContext to the container configuration in your deployment manifest - see the solution below if needed:

<details>
<summary>solution</summary>

```yaml
# rest of yaml omitted
containers:
- image: nginx:alpine
  securityContext:
    runAsNonRoot: true
    allowPrivilegeEscalation: false
    capabilities:
      drop: ["ALL"]
    seccompProfile:
      type: RuntimeDefault
# rest of yaml omitted
```

</details>

10. [10]Time to see if our deployment is working now. Reapply the manifest, then get the pods in the webserver namespace:

```bash
kubectl -n webserver apply -f deploy.yml
kubectl -n webserver get pods
```
There are still no pods found. Time to begin some deeper troubleshooting. 

11. [11]Begin by describing the deployment:

```bash
kubectl -n webserver describe deploy webserver
```
Review the conditions and events information:

```
Conditions:
  Type             Status  Reason
  ----             ------  ------
  Progressing      True    NewReplicaSetCreated
  Available        False   MinimumReplicasUnavailable
  ReplicaFailure   True    FailedCreate
OldReplicaSets:    webserver-6bc6b589d7 (0/8 replicas created)
NewReplicaSet:     webserver-84859c8bf8 (0/5 replicas created)
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  4m3s  deployment-controller  Scaled up replica set webserver-6bc6b589d7 from 0 to 10
  Normal  ScalingReplicaSet  70s   deployment-controller  Scaled up replica set webserver-84859c8bf8 from 0 to 3
  Normal  ScalingReplicaSet  70s   deployment-controller  Scaled down replica set webserver-6bc6b589d7 from 10 to 8
  Normal  ScalingReplicaSet  70s   deployment-controller  Scaled up replica set webserver-84859c8bf8 from 3 to 5
```

This tells us several key things. Firstly, that the deployment was successfully updated and attempted to create a new ReplicaSet and, secondly, that the ReplicaSet failed creation. To see why, describe the ReplicaSet:

```bash
kubectl -n webserver describe rs webserver-xxxxxxxxxx # replace with the name of your replicaset
```

12. [12]Reviewing the events for the ReplicaSet tells us what the issue is - that our `ResourceQuota` applies CPU and memory limits to the webserver namespace, meaning we have to provide this information to allow validation against the policy. Edit the `resources` stanza of your manifest to set requests and limits of 100m cpu/100Mi memory. See the solution below if needed

<details>
<summary>solution</summary>

```yaml
# rest of yaml omitted
resources:
  requests:
    cpu: 100m
    memory: 100Mi
  limits:
    cpu: 100m
    memory: 100Mi
# rest of yaml omitted
```

</details>

13. [13]Reapply the manifest and perform a `get pods` again:

```bash
kubectl -n webserver apply -f deploy.yml
```
Observe that we now have some pods, and two new issues:
  * The pods we have are all failing to create containers
  * We only have 5 pods, not the 10 replicas defined in the deployment spec

We will deal with the container creation issue first, and then the replicas.

14. [14]To investigate the container creation error, describe one of the failed pods:

```bash
kubectl -n webserver describe pod webserver-xxxxxxxxxx-xxxxx
```
This is the long arm of our pod security standard again. The PSS requires that we prevent all containers from running as root, but the standard Nginx image requires running as root in order to do things like bind port 80. 

15. [15]Edit the image and containerPort used by the deployment like so:

```yaml
# rest of yaml omitted
containers:
- image: nginxinc/nginx-unprivileged
  ports:
  - containerPort: 8080
# rest of yaml omitted
```

16. [16]Apply the manifest again: `kubectl -n webserver apply -f deploy.yml`. Confirm that there are now 5 running pods.

17. [17]The other issue that we identified was that we had only 5 pods, not the 10 specified in `deploy.yml`. This is, of course, due to the pod count limit in the ResourceQuota. If we had good reason to need all 10 replicas, we could adjust the ResourceQuota accordingly. Seeing as we don't need 10 replicas, we will edit `deploy.yml` and change the `replicas:` value to 5, to respect the quota. Make this change and apply the manifest once more.

18. [18]Time to expose the deployment. Remember that the service should be of type `ClusterIP`:

```bash
kubectl -n webserver expose deploy webserver --type=ClusterIP --port=8080
```

## 6.3 Configure Ingress
19. [19]We will now set up the ingress routing to the webserver deployment. Generate a starter ingress configuration:

```bash
kubectl -n ingress create ingress new-ingress --class=nginx --rule="/*=webserver:8080" --dry-run=client -o yaml > ingress.yml
```

20. [20]Apply the ingress configuration:

```bash
kubectl apply -f ingress.yml
```

21. [21]Retrieve the high-numbered port associated with the ingress service, and in a browser navigate to `http://<cluster-node-ip>:<service-port>`. Do you see the webserver?

22. [22]Review the logs for the webserver pods to confirm that the issue is not with the webserver itself; the requests simply aren't getting through. Why might this be?

23. [23]The answer lies in the way that ingress works - the services used as backends for the ingress are assumed to exist in the same namespace as the ingress itself. The solution to this problem is the `ExternalName` service type, which we can use to create a `webserver` service in the ingress namespace which resolves to the cluster DNS of the target service in the webserver namespace

24. [24]Review and apply the provided `solutions/06_03_ename_svc.yml` manifest to create the appropriate service into the ingress namespace:

```bash
kubectl apply -f solutions/06_03_ename-svc.yml
```
Reload the browser tab. Is the webserver reachable now?

25. [25]We have one more configuration issue to solve. The ExternalName service that we have just created creates a DNS record which is used to resolve the correct service in the webserver namespace. However, in order to do this, we need to be able to make requests to the `kube-dns` component to lookup the fully qualified service name. As this component runs in the `kube-system` namespace, egress traffic to it is currently blocked by our network policy.

26. [26]Edit the `solutions/06_01_netpol_ingress.yml` manifest and add the following egress rule _in addition to_ the existing one:

```yaml
- podSelector:
    matchLabels:
      k8s-app: kube-dns
```

27. [27]Reload the browser tab again - you should now be able to see the default "Welcome to NGINX" landing page

