## 🧩 Problem Statement

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task; failure to do so may result in a score of **0**.

**Task:**

Modify the existing Deployment `api-broker` running in the namespace `secure-zone` so that its container:

- Runs as user `30000`
- Disables privilege escalation
- Adds the `NET_BIND_SERVICE` capability

The manifest file for `api-broker` can be found at `/ckad/secure-zone-ops/api-broker.yaml`

</details>

---

## 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

**Step 1: Create namespace and directory**

```bash
kubectl create namespace secure-zone
mkdir -p /ckad/secure-zone-ops
```

**Step 2: Create the Deployment manifest without security context**

```bash
cat <<EOF > /ckad/secure-zone-ops/api-broker.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-broker
  namespace: secure-zone
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-broker
  template:
    metadata:
      labels:
        app: api-broker
    spec:
      containers:
      - name: api-broker
        image: devopstechtales/ckad-exam-questions:1.12.7
        command:
        - sh
        - -c
        - while true; do echo 'Broker Running'; sleep 10; done
EOF
```

**Step 3: Apply the manifest**

```bash
kubectl apply -f /ckad/secure-zone-ops/api-broker.yaml
```

**Step 4: Verify — no security context configured yet**

```bash
kubectl get deployment api-broker -n secure-zone
kubectl describe deployment api-broker -n secure-zone | grep -A5 "Security"
```

Output should show no security context. ✅

Scenario is ready. ✅

</details>

---

## ✅ Solution

<details>
<summary>Click to expand the solution</summary>

---

### Step 1: Check the manifest file

```bash
cat /ckad/secure-zone-ops/api-broker.yaml
```

---

### Step 2: Understand what needs to be added

| Requirement | Field in securityContext |
|---|---|
| Runs as user 30000 | `runAsUser: 30000` |
| Disable privilege escalation | `allowPrivilegeEscalation: false` |
| Add NET_BIND_SERVICE capability | `capabilities.add: ["NET_BIND_SERVICE"]` |

> All three go inside `securityContext` at **container level** — not pod level!

---

### Step 3: Edit the manifest file

```bash
vim /ckad/secure-zone-ops/api-broker.yaml
```

Add `securityContext` under the container:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-broker
  namespace: secure-zone
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-broker
  template:
    metadata:
      labels:
        app: api-broker
    spec:
      containers:
      - name: api-broker
        image: devopstechtales/ckad-exam-questions:1.15.7
        command:
        - sh
        - -c
        - while true; do echo 'Broker Running'; sleep 10; done
        securityContext:                          # ✅ container level
          runAsUser: 30000                        # ✅ runs as user 30000
          allowPrivilegeEscalation: false         # ✅ disable privilege escalation
          capabilities:
            add:
            - NET_BIND_SERVICE                    # ✅ add capability
```

Save and exit.

---

### Step 4: Apply the updated manifest

```bash
kubectl apply -f /ckad/secure-zone-ops/api-broker.yaml
```

---

### Step 5: Verify rollout completed

```bash
kubectl rollout status deployment/api-broker -n secure-zone
```

---

### Step 6: Verify security context applied

```bash
kubectl describe deployment api-broker -n secure-zone | grep -A10 "Security"
```

Expected output:
```
Security Context:
  Allow Privilege Escalation:  false
  Capabilities:
    Add: NET_BIND_SERVICE
  Run As User:  30000
```

---

### Step 7: Verify inside the pod

```bash
# check which user the container is running as
kubectl exec -it -n secure-zone deploy/api-broker -- id
```

Expected output:
```
uid=30000 gid=0(root) groups=0(root)
```

✅ Running as user 30000
✅ Privilege escalation disabled
✅ NET_BIND_SERVICE capability added


> `capabilities` and `allowPrivilegeEscalation` are **container level ONLY** — never pod level! Important for exam! 💪

</details>

---