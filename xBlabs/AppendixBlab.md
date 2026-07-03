# Appendix B - Troubleshooting
## B.1 - Install the metrics server

Understanding resource utilisation is an important part of troubleshooting. Most managed Kubernetes services come with the `Metrics Server` already installed, but we're going to manually install it in our cluster.

1. Create the appropriate objects. We're going to use `kubectl create` and pass it a github URL: `https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml` 

<details><summary>show command</summary>
<p>

```bash
kubectl create -f \
    https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

</p>
</details>
<br/>

Example output (different versions may create different objects):

```
serviceaccount/metrics-server created
clusterrole.rbac.authorization.k8s.io/system:aggregated-metrics-reader created
clusterrole.rbac.authorization.k8s.io/system:metrics-server created
rolebinding.rbac.authorization.k8s.io/metrics-server-auth-reader created
clusterrolebinding.rbac.authorization.k8s.io/metrics-server:system:auth-delegator created
clusterrolebinding.rbac.authorization.k8s.io/system:metrics-server created
service/metrics-server created
deployment.apps/metrics-server created
apiservice.apiregistration.k8s.io/v1beta1.metrics.k8s.io created
```

<br/>

2. It will be a minute or two before the metrics get popluated, but once they have, view pod metrics from all namespaces and node metrics. Use the `kubectl top` command. Which pod(s) are consuming the most resources? Which node is the busiest?

<details><summary>show command</summary>
<p>

```bash
kubectl top pods --all-namespaces
kubectl top nodes
```

</p>
</details>
<br/>

## B.2 - Install the Kubernetes Dashboard

Another tool which may prove useful when troubleshooting is the Kubernetes Dashboard. Once again, most managed services come with a pre-configured dashboard but we'll use Helm to install one on our cluster. We need to install an older version of the Helm chart and override several of the default settings in order to be able to use it with our Kubernetes configuration.

3. Add a Helm repo named `kubernetes-dashboard` which is located at `https://kubernetes.github.io/dashboard/`

<details><summary>show command</summary>
<p>

```bash
cd ~
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/ 
```

</p>
</details>
<br/>

4. Install version `6.0.8` of the chart, setting `protocolHttp` to `true` (TLS is as ever an issue), setting the `service.type` to `NodePort` and enabling the `metricsScraper`, which will integrate the dashboard with the metrics server we just installed.

<details><summary>show command</summary>
<p>

```bash
helm install kubernetes-dashboard \
    https://kubernetes.github.io/dashboard/kubernetes-dashboard \
    --set protocolHttp=true \
    --set service.type=NodePort \
    --set metricsScraper.enabled=true \
    --version "6.0.8"
```

</p>
</details>
<br/>

5. Give the dashboard permission to collect all the data it needs. We'll create a `clusterrolebinding` to bind the `cluster-admin` role to the `kubernetes-dashboard` serviceaccount in the `default` namespace. **Note**: this is overly-permissive. The dashboard doesn't require full admin rights. It's fine for a training course, but we shouldn't be doing this on a production cluster.

<details><summary>show command</summary>
<p>

```bash
kubectl create clusterrolebinding dashaccess \
    --clusterrole cluster-admin \
    --serviceaccount default:kubernetes-dashboard
```

</p>
</details>
<br/>

6. Find out the high-numbered port of your dashboard and browse to it. On our standard classroom build, you should be able to reach it at `http://k8s-controller-0:3XXXX`, where 3XXXX is your dashboard's port number.

<details><summary>show command</summary>
<p>

```bash
kubectl get service kubernetes-dashboard
```

</p>
</details>
<br/>

7. Explore the dashboard. You should be able to see charts displaying CPU and memory usage of your workloads, retrieve logs for individual pods, view configmaps and other cluster resources.

## B.3 - OPTIONAL - troubleshoot a broken YAMLfest

In the "starters" directory of this repo there is a file named "AppendixB_brokendeploy.yaml". It's a YAMLfest for a deployment that would have worked several years ago when deployment objects were first being added to Kubernetes.

Copy it into your home directory and try to `create` the deployment. It won't work initially.

Your optional task is to read the errors from the command line and make changes to the YAMLfest so that the deployment will succeed. You will need to make several changes to the file.
