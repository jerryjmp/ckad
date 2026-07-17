# 🧩 Problem Statement (RBAC - Find Correct ServiceAccount)

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

# 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `setup_q11_problem_scenario.sh` | Deploys 2 ServiceAccounts, 2 Roles (one correct, one insufficient), 2 RoleBindings, and `eagle-deployment` on the `default` SA — run before practice (re-run anytime to practice again) |

---

### 📥 Script : setup_q11_problem_scenario.sh

Run this **before you start practicing** this problem.
Re-run anytime you want to practice again after fixing.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q11: RBAC - Find Correct ServiceAccount
# setup_q11_problem_scenario.sh
# Deploys falcon-sa (correct, list perms) + web-sa (watch only),
# eagle-deployment starts on default SA (forbidden)
# Run on: controlplane node
# ============================================================

set -euo pipefail

NAMESPACE="falcon"
MANIFEST_DIR="/ckad/falcon-ops"

echo ""
echo "==========================================="
echo " CKAD Q11 — Setting up RBAC scenario..."
echo "==========================================="
echo ""

# ── Step 0: Revert solution-specific changes (fast) ────────────
# Only undoes what THIS question's solution changes: the
# eagle-deployment manifest (solution adds serviceAccountName).
# ServiceAccounts, Roles, and RoleBindings are untouched by the
# solution, so they don't need to be recreated.
echo "[0/4] Reverting any previous solution changes..."
if [ -f "$MANIFEST_DIR/eagle-deployment.yaml" ] && kubectl get namespace "$NAMESPACE" &>/dev/null; then
  cat <<EOF > "$MANIFEST_DIR/eagle-deployment.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: eagle-deployment
  namespace: $NAMESPACE
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
  kubectl apply -f "$MANIFEST_DIR/eagle-deployment.yaml"
fi
echo "  Reverted."

# ── Step 1: Create namespace and directory ─────────────────────
echo "[1/4] Ensuring namespace '$NAMESPACE' and manifest dir exist..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
sudo mkdir -p "$MANIFEST_DIR"
sudo chown "$(id -u):$(id -g)" "$MANIFEST_DIR"
echo "  Ready."

# ── Step 2: Create ServiceAccounts, Roles, RoleBindings ─────────
echo "[2/4] Creating ServiceAccounts, Roles, RoleBindings..."

kubectl create serviceaccount falcon-sa -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl create serviceaccount web-sa -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: falcon-role
  namespace: $NAMESPACE
rules:
- apiGroups: [""]
  resources: ["pods", "serviceaccounts", "deployments"]
  verbs: ["get", "list"]        # has list permission
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: web-role
  namespace: $NAMESPACE
rules:
- apiGroups: [""]
  resources: ["pods", "serviceaccounts", "deployments"]
  verbs: ["watch"]              # only watch - not enough
EOF

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: falcon-rolebinding
  namespace: $NAMESPACE
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: falcon-role
subjects:
- kind: ServiceAccount
  name: falcon-sa
  namespace: $NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: web-rolebinding
  namespace: $NAMESPACE
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: web-role
subjects:
- kind: ServiceAccount
  name: web-sa
  namespace: $NAMESPACE
EOF
echo "  Created."

# ── Step 3: Create eagle-deployment on default SA ───────────────
echo "[3/4] Writing and applying eagle-deployment.yaml (default SA)..."

cat <<EOF > "$MANIFEST_DIR/eagle-deployment.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: eagle-deployment
  namespace: $NAMESPACE
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

kubectl apply -f "$MANIFEST_DIR/eagle-deployment.yaml"

echo "  Waiting for pod to be Ready..."
kubectl wait --for=condition=ready pod -l app=eagle -n "$NAMESPACE" --timeout=120s
echo "  Pod Ready."

# ── Step 4: Verify scenario is broken ──────────────────────────
echo "[4/4] Verifying deployment logs (expect Forbidden error)..."
kubectl get all -n "$NAMESPACE"
sleep 3
kubectl logs -n "$NAMESPACE" deploy/eagle-deployment --tail=5 || true

echo ""
echo "✅ Q11 scenario is ready!"
echo ""
echo "   eagle-deployment is running on the default ServiceAccount"
echo "   and cannot list serviceaccounts. Two SAs/Roles exist —"
echo "   only falcon-sa (bound to falcon-role) has the right perms."
echo "   Manifest at: $MANIFEST_DIR/eagle-deployment.yaml"
echo "   Now go fix it! 💪"
echo ""
```

</details>

---

# ✅ Solution

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

# ↩️ Restore Cluster State

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `reset_q11_baseline.sh` | Moving to next problem? Run this to remove all Q11 changes and restore clean cluster state |

---

### 🧹 Script : reset_q11_baseline.sh

**Done with this problem? Moving to the next one?**
Run this to remove all Q11 changes and restore a clean cluster state.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q11: RBAC - Find Correct ServiceAccount
# reset_q11_baseline.sh
# ============================================================

set -euo pipefail

NAMESPACE="falcon"
MANIFEST_DIR="/ckad/falcon-ops"

echo ""
echo "==========================================="
echo " CKAD Q11 — Restoring cluster to baseline..."
echo "==========================================="
echo ""

echo "[1/2] Deleting namespace '$NAMESPACE' (Deployment, SAs, Roles, RoleBindings)..."
kubectl delete namespace "$NAMESPACE" --ignore-not-found
echo "  Waiting for namespace deletion to complete..."
while kubectl get namespace "$NAMESPACE" &>/dev/null; do
  sleep 2
done
echo "  Namespace removed."

echo "[2/2] Removing manifest directory..."
sudo rm -rf "$MANIFEST_DIR"
echo "  Manifest directory removed."

echo ""
echo "✅ Cluster is back to baseline!"
echo ""
echo "   Safe to move to next problem. 🚀"
echo ""
```

</details>

---