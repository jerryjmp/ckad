# 🧩 Problem Statement (RBAC - ServiceAccount & Role Binding)

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task; failure to do so may result in a score of **0**.

**Context:**
A Deployment requires specific RBAC permissions to function correctly.

**Task:**

1. Identify the **RBAC permissions** required by the Deployment `scraper` running in the namespace `cute-panda`.

2. Create a new **ServiceAccount** named `scraper` in the namespace `cute-panda`.

3. Check the **existing Roles** in the namespace `cute-panda` and bind the **most appropriate Role** to the new ServiceAccount `scraper`.

4. Update the Deployment `scraper` to use the new ServiceAccount `scraper`.

</details>

---

# 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `setup_q07_problem_scenario.sh` | Deploys namespace, 3 Roles, and the `scraper` Deployment on the `default` ServiceAccount — run before practice (re-run anytime to practice again) |

---

### 📥 Script : setup_q07_problem_scenario.sh

Run this **before you start practicing** this problem.
Re-run anytime you want to practice again after fixing.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q07: RBAC - ServiceAccount & Role Binding
# setup_q07_problem_scenario.sh
# Deploys 3 Roles + scraper Deployment on default ServiceAccount
# Run on: controlplane node
# ============================================================

set -euo pipefail

NAMESPACE="cute-panda"

echo ""
echo "==========================================="
echo " CKAD Q07 — Setting up RBAC scenario..."
echo "==========================================="
echo ""

# ── Step 0: Revert solution-specific changes (fast) ────────────
# Only undoes what THIS question's solution creates/changes:
# - ServiceAccount scraper
# - RoleBinding scraper-binding
# - Deployment's serviceAccountName (patched back to default)
# The 3 Roles and the Deployment itself are untouched by the
# solution, so they don't need to be recreated.
echo "[0/4] Reverting any previous solution changes..."
kubectl delete rolebinding scraper-binding -n "$NAMESPACE" --ignore-not-found
kubectl delete serviceaccount scraper -n "$NAMESPACE" --ignore-not-found
if kubectl get deployment scraper -n "$NAMESPACE" &>/dev/null; then
  kubectl patch deployment scraper -n "$NAMESPACE" \
    --type='json' -p='[{"op":"replace","path":"/spec/template/spec/serviceAccountName","value":"default"}]' 2>/dev/null || true
fi
echo "  Reverted."

# ── Step 1: Create the namespace ───────────────────────────────
echo "[1/4] Ensuring namespace '$NAMESPACE' exists..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo "  Namespace ready."

# ── Step 2: Create three Roles — only one has correct permissions ──
echo "[2/4] Creating Roles (event-reader, pod-list, pod-logs)..."

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: event-reader
  namespace: $NAMESPACE
rules:
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-list
  namespace: $NAMESPACE
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-logs
  namespace: $NAMESPACE
rules:
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]
EOF
echo "  Roles created."

# ── Step 3: Create the Deployment on the default ServiceAccount ──
echo "[3/4] Creating scraper Deployment (uses default ServiceAccount)..."

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scraper
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scraper
  template:
    metadata:
      labels:
        app: scraper
    spec:
      containers:
      - name: scraper
        image: bitnami/kubectl:latest
        command:
        - sh
        - -c
        - |
          while true; do
            kubectl get pods -n cute-panda
            sleep 10
          done
EOF

echo "  Waiting for pod to be Ready..."
kubectl wait --for=condition=ready pod -l app=scraper -n "$NAMESPACE" --timeout=120s
echo "  Pod Ready."

# ── Step 4: Verify scenario is broken ──────────────────────────
echo "[4/4] Verifying deployment logs (expect Forbidden error)..."
kubectl get all -n "$NAMESPACE"
sleep 3
kubectl logs -n "$NAMESPACE" deploy/scraper --tail=5 || true

echo ""
echo "✅ Q07 scenario is ready!"
echo ""
echo "   scraper Deployment is running but its default ServiceAccount"
echo "   lacks permission to list pods. 3 Roles exist — only one fits."
echo "   Now go fix it! 💪"
echo ""
```

</details>

---

# ✅ Solution

<details>
<summary>Click to expand the solution</summary>

---

### Step 1: Check deployment logs to identify required permission

```bash
kubectl logs -n cute-panda deploy/scraper
```

Output:
```
Error from server (Forbidden): pods is forbidden: User 
"system:serviceaccount:cute-panda:default" cannot list resource 
"pods" in API group "" in the namespace "cute-panda"
```

This tells us:
- Resource needed: `pods`
- Verb needed: `list`
- Current ServiceAccount `default` does not have this permission

---

### Step 2: Create new ServiceAccount

```bash
kubectl create serviceaccount scraper -n cute-panda
```

**Verify:**

```bash
kubectl get serviceaccount -n cute-panda
```

---

### Step 3: List existing Roles

```bash
kubectl get roles -n cute-panda
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
kubectl describe role event-reader -n cute-panda
```
```
Resources  Verbs
---------  -----
events     get, list       ← events, not pods
```

```bash
kubectl describe role pod-logs -n cute-panda
```
```
Resources  Verbs
---------  -----
pods/log   get             ← logs only, not list pods
```

```bash
kubectl describe role pod-list -n cute-panda
```
```
Resources  Verbs
---------  -----
pods       get, list       ✅ this is what we need!
```

**`pod-list` is the correct Role.**

---

### Step 4: Bind pod-list Role to scraper ServiceAccount

```bash
kubectl create rolebinding scraper-binding \
  --role=pod-list \
  --serviceaccount=cute-panda:scraper \
  --namespace=cute-panda
```

**Verify:**

```bash
kubectl get rolebinding -n cute-panda
kubectl describe rolebinding scraper-binding -n cute-panda
```

---

### Step 5: Update Deployment to use new ServiceAccount

```bash
kubectl set serviceaccount deployment/scraper scraper -n cute-panda
```

Or edit manually:

```bash
kubectl edit deployment scraper -n cute-panda
```

```yaml
spec:
  template:
    spec:
      serviceAccountName: scraper    # ✅ add this line
```

---

### Step 6: Verify rollout completed

```bash
kubectl rollout status deployment/scraper -n cute-panda
```

---

### Step 7: Check logs — error should be gone

```bash
kubectl logs -n cute-panda deploy/scraper
```

Expected output:
```
Successfully listed pods ✅
```

</details>

---

# ↩️ Restore Cluster State

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `reset_q07_baseline.sh` | Moving to next problem? Run this to remove all Q07 changes and restore clean cluster state |

---

### 🧹 Script : reset_q07_baseline.sh

**Done with this problem? Moving to the next one?**
Run this to remove all Q07 changes and restore a clean cluster state.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q07: RBAC - ServiceAccount & Role Binding
# reset_q07_baseline.sh
# ============================================================

set -euo pipefail

NAMESPACE="cute-panda"

echo ""
echo "==========================================="
echo " CKAD Q07 — Restoring cluster to baseline..."
echo "==========================================="
echo ""

echo "[1/1] Deleting namespace '$NAMESPACE' (Deployment, Roles, ServiceAccount, RoleBinding)..."
kubectl delete namespace "$NAMESPACE" --ignore-not-found
echo "  Waiting for namespace deletion to complete..."
while kubectl get namespace "$NAMESPACE" &>/dev/null; do
  sleep 2
done
echo "  Namespace removed."

echo ""
echo "✅ Cluster is back to baseline!"
echo ""
echo "   Safe to move to next problem. 🚀"
echo ""
```

</details>

---