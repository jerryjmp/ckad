## 🧩 Problem Statement

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task; failure to do so may result in a score of **0**.

**Context:**
You need to create a Pod that requests specific amounts of CPU and memory.

**Task:**

Modify the Pods of the Deployment `nginx-resources` in the namespace `pod-resources` to:

- **Request** `30m` CPU and `38Mi` memory
- Set CPU and memory **limits** to **twice** their respective requests
- Ensure the **maximum total resources** available to the Pods of Deployment `nginx-resources` match the total resources in the namespace

</details>

---

## 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

**Step 1: Create namespace**

```bash
kubectl create namespace pod-resources
```

**Step 2: Create ResourceQuota — intentionally low to simulate exam**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: pod-resources-quota
  namespace: pod-resources
spec:
  hard:
    limits.cpu: "30m"       # ❌ intentionally low - needs fixing in solution
    limits.memory: "36Mi"   # ❌ intentionally low - needs fixing in solution
EOF
```

**Step 3: Verify ResourceQuota**

```bash
kubectl describe ns pod-resources
```

Expected output:
```
Resource Quotas
  Name: pod-resources-quota
  Resource       Used  Hard
  --------       ----  ----
  limits.cpu     0     20m
  limits.memory  0     26Mi

No LimitRange resource.
```

**Step 4: Create the Deployment without resource limits**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-resources
  namespace: pod-resources
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-resources
  template:
    metadata:
      labels:
        app: nginx-resources
    spec:
      containers:
      - name: nginx-resources
        image: devopstechtales/ckad-exam-questions:1.15.7
        command:
        - sh
        - -c
        - while true; do echo 'Running'; sleep 10; done
EOF
```

**Step 5: Verify pods are failing**

```bash
kubectl get deployment nginx-resources -n pod-resources
kubectl describe replicaset -n pod-resources | grep -A5 "Error"
```

Expected:
```
NAME               READY   UP-TO-DATE   AVAILABLE
nginx-resources    0/1     0            0
```

Error:
```
Error: failed quota: must specify
limits.cpu, limits.memory
```

Scenario is ready — pods failing due to missing resources! ✅

</details>

---

## ✅ Solution

<details>
<summary>Click to expand the solution</summary>

---

### Step 1: Check existing ResourceQuota on namespace

```bash
kubectl describe ns pod-resources
```

Output:
```
Resource Quotas
  Name: pod-resources-quota
  Resource       Used  Hard
  --------       ----  ----
  limits.cpu     0     30m
  limits.memory  0     36Mi

No LimitRange resource.
```

---

### Step 2: Calculate required values

```
Given in task:
  requests.cpu    = 30m
  requests.memory = 38Mi

Limits = 2x requests:
  limits.cpu    = 30m × 2 = 60m
  limits.memory = 38Mi × 2 = 76Mi

Existing RQ hard limits:
  limits.cpu    = 30m   ❌ too low for pod limit of 60m
  limits.memory = 36Mi  ❌ too low for pod limit of 76Mi
→ RQ needs to be updated after setting pod resources
```

---

### Step 3: Update Deployment with resource requests and limits

```bash
kubectl edit deployment nginx-resources -n pod-resources
```

Add resources section under container:

```yaml
spec:
  template:
    spec:
      containers:
      - name: nginx-resources
        image: devopstechtales/ckad-exam-questions:1.15.7
        resources:
          requests:
            cpu: "30m"       # ✅ as specified in task
            memory: "38Mi"   # ✅ as specified in task
          limits:
            cpu: "60m"       # ✅ 2x request
            memory: "76Mi"   # ✅ 2x request
```

Save and exit.

---

### Step 4: Check pods — still failing due to RQ

```bash
kubectl get pods -n pod-resources
```

```
NAME                            READY   STATUS
nginx-resources-xxx-xxx         0/1     Pending   ❌ still failing!
```

```bash
kubectl describe replicaset -n pod-resources | grep Error
```

Output:
```
Error: exceeded quota: pod-resources-quota
  limited: limits.cpu=20m, limits.memory=26Mi
```

> RQ hard limits are too low — pod needs 60m cpu and 76Mi memory but RQ only allows 30m and 36Mi!

---

### Step 5: Update ResourceQuota to match pod limits

```bash
kubectl edit resourcequota pod-resources-quota -n pod-resources
```

Update hard limits to match pod limits exactly:

```yaml
spec:
  hard:
    limits.cpu: "60m"      # ✅ updated to match pod limit cpu
    limits.memory: "76Mi"  # ✅ updated to match pod limit memory
```

Save and exit.

---

### Step 6: Verify pods are now running

```bash
kubectl get deployment nginx-resources -n pod-resources
kubectl get pods -n pod-resources
```

Expected:
```
NAME               READY   UP-TO-DATE   AVAILABLE
nginx-resources    1/1     1            1          ✅
```

---

### Step 7: Verify ResourceQuota usage matches hard limits

```bash
kubectl describe ns pod-resources
```

Expected output:
```
Resource Quotas
  Name: pod-resources-quota
  Resource       Used   Hard
  --------       ----   ----
  limits.cpu     60m    60m    ✅ used = hard (exactly matches)
  limits.memory  76Mi   76Mi   ✅ used = hard (exactly matches)
```

---

### Step 8: Verify resource settings on pod

```bash
kubectl describe pod -n pod-resources | grep -A8 "Limits"
```

Expected:
```
Limits:
  cpu:     60m
  memory:  76Mi
Requests:
  cpu:     30m
  memory:  38Mi
```

</details>

---