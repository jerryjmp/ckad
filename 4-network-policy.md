## 📄 CKAD Question 4 — Network Policy


### 🧩 Problem Statement

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task; failure to do so may result in a score of **0**.

**Context:**
You need to restrict a Pod so it can only communicate with two specific Pods, and no others.

**Task:**

Update the Pod `app-connector` in the namespace `netpol-lab` so that it can **only communicate** with the Pods `frontend` and `datastore` using the **existing NetworkPolicies**.

> **Do NOT create, modify, or delete any NetworkPolicies** during this task — only use the existing ones.

</details>

---

### 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

**Step 1: Create the namespace**

```bash
kubectl create namespace netpol-lab
```

**Step 2: Create the three Pods**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: netpol-lab
  labels:
    app: frontend
    item: netpol-lab
spec:
  containers:
  - name: frontend
    image: devopstechtales/ckad-exam-questions:netpol-fe
---
apiVersion: v1
kind: Pod
metadata:
  name: datastore
  namespace: netpol-lab
  labels:
    app: datastore
    item: netpol-lab
spec:
  containers:
  - name: datastore
    image: devopstechtales/ckad-exam-questions:netpol-datastore
---
apiVersion: v1
kind: Pod
metadata:
  name: app-connector
  namespace: netpol-lab
  labels:
    app: app-connector
    item: netpol-lab
spec:
  containers:
  - name: app-connector
    image: devopstechtales/ckad-exam-questions:netpol-app-connector
---
apiVersion: v1
kind: Pod
metadata:
  name: extra-pod
  namespace: netpol-lab
  labels:
    app: extra-pod
    item: netpol-lab
spec:
  containers:
  - name: extra-pod
    image: devopstechtales/ckad-exam-questions:netpol-extra-pod
EOF
```

**Step 3: Create the NetworkPolicies**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: access-frontend
  namespace: netpol-lab
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          frontend-access: "true"
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: access-datastore
  namespace: netpol-lab
spec:
  podSelector:
    matchLabels:
      app: datastore
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          datastore-access: "true"
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: all-access
  namespace: netpol-lab
spec:
  podSelector:
    matchLabels:
      all-access: "true"
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - {}
  egress:
  - {}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: netpol-lab
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF
```

**Step 4: Verify**

```bash
kubectl get pods -n netpol-lab --show-labels
kubectl get networkpolicy -n netpol-lab
```

You should see:
- 3 pods running: `frontend`, `datastore`, `app-connector`
- 4 NetworkPolicies: `access-frontend`, `access-datastore`, `all-access`, `default-deny` ✅

Scenario is ready. ✅

</details>

---

### ✅ Solution

<details>
<summary>Click to expand the solution</summary>

---

### Step 1: List existing NetworkPolicies

```bash
kubectl get networkpolicy -n netpol-lab
```

Output:
```
NAME               POD-SELECTOR
access-datastore   app=datastore
access-frontend    app=frontend
all-access         all-access=true
default-deny       <none>
```

---

### Step 2: Describe NetworkPolicies to find required labels

**Check access-frontend:**

```bash
kubectl describe networkpolicy access-frontend -n netpol-lab
```

Key output:
```
PodSelector:  app=frontend
Ingress - From PodSelector: frontend-access=true
Egress  - To PodSelector:   frontend-access=true
```

> So any pod that wants to talk to `frontend` must have label `frontend-access=true`

---

**Check access-datastore:**

```bash
kubectl describe networkpolicy access-datastore -n netpol-lab
```

Key output:
```
PodSelector:  app=datastore
Ingress - From PodSelector: datastore-access=true
Egress  - To PodSelector:   datastore-access=true
```

> So any pod that wants to talk to `datastore` must have label `datastore-access=true`

---

### Step 3: Add required labels to app-connector

```bash
kubectl label pod app-connector -n netpol-lab frontend-access=true
kubectl label pod app-connector -n netpol-lab datastore-access=true
```

---

### Step 4: Verify labels applied

```bash
kubectl get pod app-connector -n netpol-lab --show-labels
```

Expected output:
```
NAME            LABELS
app-connector   app=app-connector,item=netpol-lab,frontend-access=true,datastore-access=true
```

✅ `app-connector` can now communicate with `frontend`
✅ `app-connector` can now communicate with `datastore`
✅ No new NetworkPolicies were created or modified

</details>

---