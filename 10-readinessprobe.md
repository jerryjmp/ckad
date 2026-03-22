## 🧩 Problem Statement

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task; failure to do so may result in a score of **0**.

**Task:**

A Deployment named `web-probe` in the namespace `staging-ops` runs a web application on port `80`. Modify the Deployment to add a **readiness probe** with the following configuration:

- Path: `/healthz/return200`
- `initialDelaySeconds`: `15`
- `periodSeconds`: `20`

</details>

---

## 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

**Step 1: Create namespace**

```bash
kubectl create namespace staging-ops
```


**Step 2: Create the Deployment without readiness probe**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-probe
  namespace: staging-ops
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-probe
  template:
    metadata:
      labels:
        app: web-probe
    spec:
      containers:
      - name: web-probe
        image: devopstechtales/ckad-exam-questions:readiness-probe
        ports:
        - containerPort: 80
EOF
```

**Step 4: Verify — no readiness probe configured yet**

```bash
kubectl get deployment web-probe -n staging-ops
kubectl describe deployment web-probe -n staging-ops | grep -i readiness
```

Output should show nothing for readiness — confirming no probe exists yet. ✅

Scenario is ready. ✅

</details>

---

## ✅ Solution

<details>
<summary>Click to expand the solution</summary>

---

### Step 1: Edit the Deployment

```bash
kubectl edit deployment web-probe -n staging-ops
```

Find the `containers` section and add `readinessProbe`:

```yaml
spec:
  template:
    spec:
      containers:
      - name: web-probe
        image: devopstechtales/ckad-exam-questions:readiness-probe
        ports:
        - containerPort: 80
        readinessProbe:             # ✅ add from here
          httpGet:
            path: /healthz/return200
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 20         # ✅ to here
```

Save and exit.

---

### Step 2: Verify rollout

```bash
kubectl rollout status deployment/web-probe -n staging-ops
```

---

### Step 3: Verify readiness probe is configured

```bash
kubectl describe deployment web-probe -n staging-ops | grep -A8 "Readiness"
```

Expected output:
```
Readiness:  http-get http://:80/healthz/return200
            delay=15s
            period=20s
            success=1
            failure=3
```

---

### Step 4: Verify pods are Ready

```bash
kubectl get pods -n staging-ops
```

Expected:
```
NAME                        READY   STATUS    RESTARTS
web-probe-xxx-xxx           1/1     Running   0
web-probe-xxx-xxx           1/1     Running   0
```

> `1/1` means pod passed readiness probe and is ready to receive traffic ✅

</details>

---