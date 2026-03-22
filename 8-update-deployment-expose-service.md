## 🧩 Problem Statement

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task; failure to do so may result in a score of **0**.

**Task:**

1. Update the Deployment `web-frontend` in the namespace `app-team`:
   - Scale it to run **3 Pod replicas**
   - Add the label `tier: proxy` to the **Pods**

2. Create a **NodePort Service** named `gateway` in the namespace `app-team` to expose the Deployment `web-frontend` on TCP port `80`

</details>

---
 
## 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

**Step 1: Create namespace**

```bash
kubectl create namespace app-team
```

**Step 2: Create the Deployment**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-frontend
  namespace: app-team
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-frontend
  template:
    metadata:
      labels:
        app: web-frontend 
    spec:
      containers:
      - name: web-frontend
        image: devopstechtales/ckad-exam-questions:1.15.7
        command:
        - sh
        - -c
        - while true; do echo 'Web Frontend Running'; sleep 10; done
        ports:
        - containerPort: 81
EOF
```

**Step 3: Verify**

```bash
kubectl get deployment web-frontend -n app-team
kubectl get pods -n app-team --show-labels
```

You should see:
- 1 replica running
- Pods have only label `app: web-frontend`
- No Service exists yet ✅

Scenario is ready. ✅

</details>

---

## ✅ Solution

<details>
<summary>Click to expand the solution</summary>

---

### Step 1: Scale Deployment to 3 replicas

```bash
kubectl scale deployment web-frontend \
  --replicas=3 \
  -n app-team
```

**Verify:**

```bash
kubectl get deployment web-frontend -n app-team
```

Expected:
```
NAME           READY   UP-TO-DATE   AVAILABLE
web-frontend   3/3     3            3
```

---

### Step 2: Add label tier: proxy to the Pods

This means adding the label to the **Pod template** inside the Deployment — not just the pods directly.

```bash
kubectl edit deployment web-frontend -n app-team
```

Find the `template.metadata.labels` section and add `tier: proxy`:

```yaml
spec:
  template:
    metadata:
      labels:
        app: web-frontend
        tier: proxy          # ✅ add this line
```

Save and exit — this triggers a rollout automatically.

Or use patch command directly:

```bash
kubectl patch deployment web-frontend -n app-team \
  --type=json \
  -p='[{"op":"add","path":"/spec/template/metadata/labels/tier","value":"proxy"}]'
```

**Verify pods have new label:**

```bash
kubectl get pods -n app-team --show-labels
```

Expected:
```
NAME                          LABELS
web-frontend-xxx-xxx   app=web-frontend,tier=proxy
web-frontend-xxx-xxx   app=web-frontend,tier=proxy
web-frontend-xxx-xxx   app=web-frontend,tier=proxy
```

---

### Step 3: Create NodePort Service


```bash
kubectl expose deployment web-frontend \
  --name=gateway \
  --type=NodePort \
  --port=81 \
  --target-port=81 \
  --namespace=app-team
```

---

### Step 4: Verify Service and Endpoints

```bash
kubectl get svc gateway -n app-team
```

Expected:
```
NAME      TYPE       CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
gateway   NodePort   10.96.x.x     <none>        81:3XXXX/TCP   10s
```

```bash
kubectl get endpoints gateway -n app-team
```

You should see **3 pod IPs** listed — one for each replica. ✅

---

</details>
