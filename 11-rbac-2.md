## 🧩 Problem Statement

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task; failure to do so may result in a score of **0**.

**Context:**
A Pod from the Deployment `eagle-deployment` in the namespace `falcon` is logging errors.

**Task:**

1. View the logs to identify the error message. The error will include:
   ```
   User "system:serviceaccount:falcon:default" cannot list resource
   "serviceaccounts" in API group "" in the namespace "falcon"
   ```

2. Update the Deployment `eagle-deployment` to resolve the error in the Pod logs.
   > The manifest file for `eagle-deployment` can be found at `/ckad/falcon-ops/eagle-deployment.yaml`

</details>

---

## 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

**Step 1: Create namespace**

```bash
kubectl create namespace falcon
```

**Step 2: Create directory and manifest file**

```bash
mkdir -p /ckad/falcon-ops
```

**Step 3: Create ServiceAccounts**

```bash
kubectl create serviceaccount falcon-sa -n falcon
kubectl create serviceaccount web-sa -n falcon
# default SA already exists automatically
```

**Step 4: Create Roles**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: falcon-role
  namespace: falcon
rules:
- apiGroups: [""]
  resources: ["pods", "serviceaccounts", "deployments"]
  verbs: ["get", "list"]        # ✅ has list permission
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: web-role
  namespace: falcon
rules:
- apiGroups: [""]
  resources: ["pods", "serviceaccounts", "deployments"]
  verbs: ["watch"]              # ❌ only watch - not enough
EOF
```

**Step 5: Create RoleBindings**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: falcon-rolebinding
  namespace: falcon
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: falcon-role
subjects:
- kind: ServiceAccount
  name: falcon-sa
  namespace: falcon
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: web-rolebinding
  namespace: falcon
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: web-role
subjects:
- kind: ServiceAccount
  name: web-sa
  namespace: falcon
EOF
```

**Step 6: Create Deployment manifest file and apply**

```bash
cat <<EOF > /ckad/falcon-ops/eagle-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: eagle-deployment
  namespace: falcon
spec:
  replicas: 1
  selector:
    matchLabels:
      app: eagle
  template:
    metadata:
      labels:
        app: eagle
    spec:
      # no serviceAccountName set - uses default SA
      containers:
      - name: eagle
        image: bitnami/kubectl:latest
        command:
        - sh
        - -c
        - |
          while true; do
            kubectl get serviceaccounts -n falcon
            sleep 10
          done
EOF

kubectl apply -f /ckad/falcon-ops/eagle-deployment.yaml
```

**Step 7: Verify logs show error**

```bash
kubectl logs -n falcon deploy/eagle-deployment
```

Expected output:
```
Error from server (Forbidden): serviceaccounts is forbidden:
User "system:serviceaccount:falcon:default" cannot list resource
"serviceaccounts" in API group "" in the namespace "falcon"
```

Scenario is ready. ✅

</details>

---

## ✅ Solution

<details>
<summary>Click to expand the solution</summary>

---

### Step 1: Check deployment logs to identify error

```bash
kubectl logs -n falcon deploy/eagle-deployment
```

Output:
```
Error from server (Forbidden): serviceaccounts is forbidden:
User "system:serviceaccount:falcon:default" cannot list resource
"serviceaccounts" in API group "" in the namespace "falcon"
```

Key information from error:
- Current SA: `default`
- Resource needed: `serviceaccounts`
- Verb needed: `list`

---

### Step 2: Check existing ServiceAccounts

```bash
kubectl get serviceaccounts -n falcon
```

Output:
```
NAME        SECRETS   AGE
default     0         10m
falcon-sa   0         10m
web-sa      0         10m
```

Three SAs exist — `default` is causing error, need to find correct one.

---

### Step 3: Check existing RoleBindings

```bash
kubectl get rolebindings -n falcon
```

Output:
```
NAME                ROLE               AGE
falcon-rolebinding  Role/falcon-role   10m
web-rolebinding     Role/web-role      10m
```

---

### Step 4: Describe RoleBindings to find which SA is bound to which Role

```bash
kubectl describe rolebinding falcon-rolebinding -n falcon
```

Output:
```
Role:
  Kind:  Role
  Name:  falcon-role
Subjects:
  Kind            Name       Namespace
  ----            ----       ---------
  ServiceAccount  falcon-sa  falcon
```

```bash
kubectl describe rolebinding web-rolebinding -n falcon
```

Output:
```
Role:
  Kind:  Role
  Name:  web-role
Subjects:
  Kind            Name    Namespace
  ----            ----    ---------
  ServiceAccount  web-sa  falcon
```

---

### Step 5: Describe both Roles to find correct permissions

```bash
kubectl describe role falcon-role -n falcon
```

Output:
```
Resources          Verbs
---------          -----
pods               get, list   ✅
serviceaccounts    get, list   ✅
deployments        get, list   ✅
```

```bash
kubectl describe role web-role -n falcon
```

Output:
```
Resources          Verbs
---------          -----
pods               watch       ❌
serviceaccounts    watch       ❌
deployments        watch       ❌
```

**Result:**
- `falcon-role` has `list` permission on `serviceaccounts` ✅
- `falcon-role` is bound to `falcon-sa` ✅
- So `falcon-sa` is the correct ServiceAccount to use

---

### Step 6: Update the manifest file with correct ServiceAccount

```bash
vim /ckad/falcon-ops/eagle-deployment.yaml
```

Add `serviceAccountName` under `spec.template.spec`:

```yaml
spec:
  template:
    spec:
      serviceAccountName: falcon-sa    # ✅ add this line
      containers:
      - name: eagle
```

Save and exit.

---

### Step 7: Apply the updated manifest

```bash
kubectl apply -f /ckad/falcon-ops/eagle-deployment.yaml
```

---

### Step 8: Verify rollout completed

```bash
kubectl rollout status deployment/eagle-deployment -n falcon
```

---

### Step 9: Check logs — error should be resolved

```bash
kubectl logs -n falcon deploy/eagle-deployment
```

Expected output:
```
NAME        SECRETS   AGE
default     0         15m
falcon-sa   0         15m
web-sa      0         15m
```

✅ No more Forbidden error
✅ ServiceAccounts listed successfully

</details>

---