## 🧩 Problem Statement

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task; failure to do so may result in a score of **0**.

**Context:**
A Deployment requires specific RBAC permissions to function correctly.

**Task:**

1. Identify the **RBAC permissions** required by the Deployment `monitor` running in the namespace `blue-falcon`.

2. Create a new **ServiceAccount** named `monitor` in the namespace `blue-falcon`.

3. Check the **existing Roles** in the namespace `blue-falcon` and bind the **most appropriate Role** to the new ServiceAccount `monitor`.

4. Update the Deployment `monitor` to use the new ServiceAccount `monitor`.

</details>

---

## 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

---

**Step 1: Create namespace**

```bash
kubectl create namespace blue-falcon
```

---

**Step 2: Create three Roles — only one has correct permissions**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: event-reader
  namespace: blue-falcon
rules:
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-list
  namespace: blue-falcon
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-logs
  namespace: blue-falcon
rules:
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]
EOF
```

---

**Step 3: Create the Deployment that tries to list pods using default ServiceAccount**

```
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: monitor
  namespace: blue-falcon
spec:
  replicas: 1
  selector:
    matchLabels:
      app: monitor
  template:
    metadata:
      labels:
        app: monitor
    spec:
      containers:
      - name: monitor
        image: bitnami/kubectl:latest
        command:
        - sh
        - -c
        - |
          while true; do
            kubectl get pods -n blue-falcon
            sleep 10
          done
EOF
```

---

**Step 5: Verify deployment is running and logs show error**

```bash
kubectl get all -n blue-falcon
kubectl logs -n blue-falcon deploy/monitor
```

Expected log output:
```
Error from server (Forbidden): pods is forbidden: User 
"system:serviceaccount:blue-falcon:default" cannot list resource 
"pods" in API group "" in the namespace "blue-falcon"
```

Scenario is ready. ✅

</details>

---

### ✅ Solution

<details>
<summary>Click to expand the solution</summary>

---

### Step 1: Check deployment logs to identify required permission

```bash
kubectl logs -n blue-falcon deploy/monitor
```

Output:
```
Error from server (Forbidden): pods is forbidden: User 
"system:serviceaccount:blue-falcon:default" cannot list resource 
"pods" in API group "" in the namespace "blue-falcon"
```

This tells us:
- Resource needed: `pods`
- Verb needed: `list`
- Current ServiceAccount `default` does not have this permission

---

### Step 2: Create new ServiceAccount

```bash
kubectl create serviceaccount monitor -n blue-falcon
```

**Verify:**

```bash
kubectl get serviceaccount -n blue-falcon
```

---

### Step 3: List existing Roles

```bash
kubectl get roles -n blue-falcon
```

Output:
```
NAME           CREATED AT
event-reader   2026-01-01T00:00:00Z
pod-list       2026-01-01T00:00:00Z
pod-logs       2026-01-01T00:00:00Z
```

**Describe each Role to find the correct one:**

```bash
kubectl describe role event-reader -n blue-falcon
```
```
Resources  Verbs
---------  -----
events     get, list       ← events, not pods
```

```bash
kubectl describe role pod-logs -n blue-falcon
```
```
Resources  Verbs
---------  -----
pods/log   get             ← logs only, not list pods
```

```bash
kubectl describe role pod-list -n blue-falcon
```
```
Resources  Verbs
---------  -----
pods       get, list       ✅ this is what we need!
```

**`pod-list` is the correct Role.**

---

### Step 4: Bind pod-list Role to monitor ServiceAccount

```bash
kubectl create rolebinding monitor-binding \
  --role=pod-list \
  --serviceaccount=blue-falcon:monitor \
  --namespace=blue-falcon
```

**Verify:**

```bash
kubectl get rolebinding -n blue-falcon
kubectl describe rolebinding monitor-binding -n blue-falcon
```

---

### Step 5: Update Deployment to use new ServiceAccount

```bash
kubectl set serviceaccount deployment/monitor monitor -n blue-falcon
```

Or edit manually:

```bash
kubectl edit deployment monitor -n blue-falcon
```

```yaml
spec:
  template:
    spec:
      serviceAccountName: monitor    # ✅ add this line
```

---

### Step 6: Verify rollout completed

```bash
kubectl rollout status deployment/monitor -n blue-falcon
```

---

### Step 7: Check logs — error should be gone

```bash
kubectl logs -n blue-falcon deploy/monitor
```

Expected output:
```
Successfully listed pods ✅
```


</details>

---