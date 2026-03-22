## 📄 CKAD Question 2 — Modify Container Name and Image


### 🧩 Problem Statement

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task.

**Task:**

Update the existing Deployment `alpine-runner` running in the namespace `rapid-fire`. **Do NOT delete the existing Deployment**, as this will result in a score of 0.

1. Change the **container name** to `core`.
2. Change the **container image** to `devopstechtales/ckad-exam-questions:core`.
3. Ensure the changes to the Deployment `alpine-runner` in the namespace `rapid-fire` are **successfully applied**.

</details>

---

### 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

**Step 1: Create the namespace**

```bash
kubectl create namespace rapid-fire
```

**Step 2: Create the Deployment**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alpine-runner
  namespace: rapid-fire
spec:
  replicas: 1
  selector:
    matchLabels:
      app: alpine-runner
  template:
    metadata:
      labels:
        app: alpine-runner
    spec:
      containers:
      - name: fun
        image: devopstechtales/ckad-exam-questions:fun
        command:
        - sh
        - -c
        - while true; do echo 'Container Running'; sleep 600; done
        imagePullPolicy: IfNotPresent
EOF
```

**Step 3: Add paused: true to simulate exam condition**

```bash
kubectl patch deployment alpine-runner -n rapid-fire \
  -p '{"spec":{"paused": true}}'
```

**Step 4: Verify**

```bash
kubectl get deployment alpine-runner -n rapid-fire
kubectl describe deployment alpine-runner -n rapid-fire
```

Scenario is ready. ✅

</details>

---

### ✅ Solution

<details>
<summary>Click to expand the solution</summary>

---

### Step 1: Edit the Deployment

```bash
kubectl edit deployment alpine-runner -n rapid-fire
```

Inside the editor, find the `containers` section:

```yaml
spec:
  template:
    spec:
      containers:
      - name: fun    # change this to core
        image: devopstechtales/ckad-exam-questions:fun  # change version to core
```

Change it to:

```yaml
spec:
  template:
    spec:
      containers:
      - name: core                                        # ✅ container name changed
        image: devopstechtales/ckad-exam-questions:core   # ✅ image tag changed
```

Also find the `paused` field and either **remove it** or set it to `false`:

```yaml
spec:
  paused: false    # ✅ unpause to trigger rollout
```

Save and exit.

---

### Step 2: Verify rollout triggered

```bash
kubectl rollout status deployment/alpine-runner -n rapid-fire
```

Expected output:
```
deployment "alpine-runner" successfully rolled out
```

---

### Step 3: Confirm changes applied

```bash
kubectl describe deployment alpine-runner -n rapid-fire | grep -E "Name:|Image:"
```

Expected output:
```
Name:         core
Image:        devopstechtales/ckad-exam-questions:core
```

Or check via:

```bash
kubectl get deployment alpine-runner -n rapid-fire -o jsonpath=\
'{.spec.template.spec.containers[*].name}'
```

```bash
kubectl get deployment alpine-runner -n rapid-fire -o jsonpath=\
'{.spec.template.spec.containers[*].image}'
```

</details>

---