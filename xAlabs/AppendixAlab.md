# Appendix A - Design Patterns
## A.1 - Init Containers

In this exercise, we'll look at yet another way to customise the home page for a web server, this time using initContainers.

1. Create a YAMLfest for a deployment named `init-web` running the `nginx` image. Give it 3 replicas.

<details><summary>show command</summary>
<p>

```bash
kubectl create deployment init-web --image=nginx --replicas=3 --dry-run=client -o yaml > init-web.yaml
```

</p>
</details>
<br/>

2. Add a list of `volumes` to the pod specification. Add an `emptyDir` named `init-vol`. Mount the volume in the `nginx` container at a `mountPath` of `/usr/share/nginx/html`

<details><summary>show YAML</summary>
<p>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: init-web
  name: init-web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: init-web
  template:
    metadata:
      labels:
        app: init-web
    spec:
      containers:
      - image: nginx
        name: nginx
# ------ Add these lines ------
        volumeMounts:
        - name: init-vol
          mountPath: /usr/share/nginx/html
      volumes:
      - name: init-vol
        emptyDir: {}
# -----------------------------
```

</p>
</details>
<br/>

3. Edit the YAMLfest to include an `initContainers` list containing a single container named `init-cont` using the `alpine` image. Mount the `init-vol` volume in the initContainer at `/init`. The `command` to pass to this container should create a file named `index.html` in the `/init` directory. Feel free to customise the welcome message.

<details><summary>show YAML</summary>
<p>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: init-web
  name: init-web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: init-web
  template:
    metadata:
      labels:
        app: init-web
    spec:
      containers:
      - image: nginx
        name: nginx
        volumeMounts:
        - name: init-vol
          mountPath: /usr/share/nginx/html
# ------ Add these lines ------
      initContainers:
      - name: init-cont
        image: alpine
        command:
          - sh
          - "-c"
          - |
            echo "<h1>Welcome to my initContainer homepage! </h1>" >> "/init/index.html"
            sleep 30
        volumeMounts:
          - name: init-vol
            mountPath: "/init"
# ------------------------------
      volumes:
        - name: init-vol
          emptyDir: {}
```

</p>
</details>
<br/>

4. `create` and `expose` the deployment, then curl the service's IP address.

<details><summary>show command</summary>
<p>

```bash
kubectl create -f init-web.yaml
kubectl expose deployment init-web --port=80
curl $(kubectl get service init-web --no-headers -o=custom-columns=ip:.spec.clusterIP)
```

</p>
</details>
<br/>

<details><summary>Stretch goal - optional exercise</summary>
<p>

5. **Optional stretch goal** add an Ingress rule for the new init-web service.

</p>
</details>
<br/>

## A.2 Sidecar Pattern

In this exercise, we'll use a *sidecar* container to continuously synchronise a website running in Kubernetes with a git repository. Yes, it is indeed **yet another** way to customise the home page! If you already have a github account, that's great. If you don't already have a github account, you can either create one now using the instructions that follow, or just use our repository, skipping steps 6, 7 and 8 below. It won't be as much fun though because with your own repository, you'll be able to make changes and see them happening 'live'.

6. If you don't already have a GitHub account, you'll need to create one at [Join GitHub](https://github.com/join?source=header-home). This will only take a few moments and you can use any email address that you own.

7. Sign in to GitHub and find the sample application. This can be found at https://github.com/qalearning/qakf-sidecar-lab.git

8. Click on the Fork button to copy the repository into your own account

![GitHub fork](https://s3.eu-west-2.amazonaws.com/qal-resources/QAKF/ForkSidercarRepo.png)

9. Create a YAMLfest for a deployment named `git-web` running the `nginx` image. Give it 3 replicas.

<details><summary>show command</summary>
<p>

```bash
kubectl create deployment git-web --image=nginx --replicas=3 --dry-run=client -o yaml > git-web.yaml
```

</p>
</details>
<br/>

10. Add a list of `volumes` to the pod specification. Add an `emptyDir` named `git-vol`. Mount the volume in the `nginx` container at a `mountPath` of `/usr/share/nginx/`

<details><summary>show YAML</summary>
<p>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: git-web
  name: git-web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: git-web
  strategy: {}
  template:
    metadata:
      labels:
        app: git-web
    spec:
      containers:
      - image: httpd
        name: httpd
# ------ Add these lines ------
        volumeMounts:
        - name: git-vol
          mountPath: /usr/local/apache2/htdocs/
      volumes:
      - name: git-vol
        emptyDir: {}
# -----------------------------
```

</p>
</details>
<br/>

11. Edit the YAMLfest to add a container named `git-sync` using the `k8s.gcr.io/git-sync:v3.1.6` image. Mount the `git-vol` volume in the new container at `/tmp/git`. You'll need to specify some environment variables for this image to point it at the right repository / branch.

**name** | **value**
-|-
GIT_SYNC_REPO | https://github.com/qalearning/qakf-sidecar-lab.git (or your repo URL)
GIT_SYNC_BRANCH | main
GIT_SYNC_DEPTH | "1"
GIT_SYNC_DEST | "html"

<details><summary>show YAML</summary>
<p>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: git-web
  name: git-web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: git-web
  strategy: {}
  template:
    metadata:
      labels:
        app: git-web
    spec:
      containers:
      - image: nginx
        name: git-web
        volumeMounts:
        - name: git-vol
          mountPath: /usr/share/nginx/
# ------ Add these lines ------
      - name: git-sync
        image: k8s.gcr.io/git-sync:v3.1.6
        volumeMounts:
        - name: git-vol
          mountPath: /tmp/git
        env:
          - name: GIT_SYNC_REPO
            value: https://github.com/qalearning/qakf-sidecar-lab.git
          - name: GIT_SYNC_BRANCH
            value: main
          - name: GIT_SYNC_DEPTH
            value: "1"
          - name: GIT_SYNC_DEST
            value: "html"
# -------------------------------
      volumes:
      - name: git-vol
        emptyDir: {}
```

</p>
</details>
<br/>

12. `create` and `expose` the deployment.

<details><summary>show command</summary>
<p>

```bash
kubectl create -f git-web.yaml
kubectl expose deployment git-web --type=NodePort --port=80
```

</p>
</details>
<br/>

13. Find the service's IP address and curl it (or browse to it).

14. In GitHub, in your git-sidecar repo, navigate to `index.html` and click on the pencil icon to edit the file. You should, of course, clone a repo to edit files, but we're only making a tiny change here so it's OK. Honest!

15. Modify the message to say something personal to you. Or just put a "v2" at the end of the header. Feel free to go wild!

16. Modify the commit message to say "updated index.html" and click ""Commit changes".

17. Give it a few seconds (the default interval is 10 seconds) and then curl or browse to the service again. You should see your modified home page.

<details><summary>Stretch goal - optional exercise</summary>
<p>

18. **Optional stretch goal** Guess what it is?! Add an Ingress rule for the new git-web service. Or make your web site a little bit more interesting.

</p>
</details>
<br/>

19. That's it, you're done! Let your instructor know that you've finished the lab.