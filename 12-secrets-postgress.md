# 🧩 Problem Statement (Move Hardcoded Secrets to a Secret)

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task; failure to do so may result in a score of **0**.

**Context:**
You need to move hardcoded secrets in a Pod's environment variables to a Kubernetes Secret and use the Secret in the Pod.

**Task:**

1. Create a new Secret named `postgres-creds` in the namespace `data-layer`. It must contain the **three secret values** currently hardcoded in the environment variables of the Pods from the Deployment `postgres-db` running in the namespace `data-layer`. Use the following keys:
   - `username`
   - `database`
   - `password`

2. Modify the Deployment `postgres-db` to use the new Secret. Set the environment variables so their values are taken from the `username`, `database`, and `password` keys of the new Secret.

   > **Do NOT delete the existing Deployment**, as this will result in a lower score.

</details>

---

# 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `setup_q12_problem_scenario.sh` | Deploys `postgres-db` with hardcoded env vars, no Secret exists yet — run before practice (re-run anytime to practice again) |

---

### 📥 Script : setup_q12_problem_scenario.sh

Run this **before you start practicing** this problem.
Re-run anytime you want to practice again after fixing.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q12: Move Hardcoded Secrets to a Secret
# setup_q12_problem_scenario.sh
# Deploys postgres-db with hardcoded env vars, no Secret exists
# Run on: controlplane node
# ============================================================

set -euo pipefail

NAMESPACE="data-layer"
DEPLOYMENT="postgres-db"

echo ""
echo "==========================================="
echo " CKAD Q12 — Setting up Secrets scenario..."
echo "==========================================="
echo ""

# ── Step 0: Revert solution-specific changes (fast) ────────────
# Only undoes what THIS question's solution creates/changes:
# - Secret postgres-creds (created by solution → deleted)
# - Deployment env vars (switched to secretKeyRef by solution →
#   Step 2 below re-applies the full Deployment with hardcoded
#   values, which overwrites any valueFrom edits in one shot)
echo "[0/2] Reverting any previous solution changes..."
kubectl delete secret postgres-creds -n "$NAMESPACE" --ignore-not-found
echo "  Reverted (Secret removed; Deployment env reset in next step)."

# ── Step 1: Create the namespace ───────────────────────────────
echo "[1/2] Ensuring namespace '$NAMESPACE' exists..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo "  Namespace ready."

# ── Step 2: Apply Deployment with hardcoded env vars ────────────
echo "[2/2] Applying $DEPLOYMENT with hardcoded env vars..."

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $DEPLOYMENT
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres-db
  template:
    metadata:
      labels:
        app: postgres-db
    spec:
      containers:
      - name: postgres-db
        image: postgres:15
        env:
        - name: POSTGRES_USER
          value: "admin"
        - name: POSTGRES_DB
          value: "myappdb"
        - name: POSTGRES_PASSWORD
          value: "S3cur3P@ss!"
EOF

echo "  Waiting for pod to be Ready..."
kubectl wait --for=condition=ready pod -l app=postgres-db -n "$NAMESPACE" --timeout=120s
echo "  Pod Ready."

echo "  Verifying hardcoded values are visible..."
kubectl describe deployment "$DEPLOYMENT" -n "$NAMESPACE" | grep -A6 "Environment"

echo ""
echo "✅ Q12 scenario is ready!"
echo ""
echo "   postgres-db is running with hardcoded credentials in env vars."
echo "   No postgres-creds Secret exists yet."
echo "   Now go fix it! 💪"
echo ""
```

</details>

---

# ✅ Solution

<details>
<summary>Click to expand the solution</summary>

---

### Step 1: Check the Deployment to find hardcoded values

```bash
kubectl describe deployment postgres-db -n data-layer | grep -A6 "Environment"
```

Output:
```
Environment:
  POSTGRES_USER:      admin
  POSTGRES_DB:        myappdb
  POSTGRES_PASSWORD:  S3cur3P@ss!
```

Note down all three values — these go into the Secret.

---

### Step 2: Create the Secret with those values

```bash
kubectl create secret generic postgres-creds \
  --from-literal=username=admin \
  --from-literal=database=myappdb \
  --from-literal=password=S3cur3P@ss! \
  --namespace=data-layer
```

**Verify Secret created:**

```bash
kubectl get secret postgres-creds -n data-layer
kubectl describe secret postgres-creds -n data-layer
```

Output:
```
Name:         postgres-creds
Namespace:    data-layer
Type:         Opaque

Data
====
database:  7 bytes
password:  11 bytes
username:  5 bytes
```

> Values are stored base64 encoded — never shown in plain text ✅

---

### Step 3: Update Deployment to use Secret

```bash
kubectl edit deployment postgres-db -n data-layer
```

**Before (hardcoded):**
```yaml
env:
- name: POSTGRES_USER
  value: "admin"
- name: POSTGRES_DB
  value: "myappdb"
- name: POSTGRES_PASSWORD
  value: "S3cur3P@ss!"
```

**After (from Secret):**
```yaml
env:
- name: POSTGRES_USER
  valueFrom:
    secretKeyRef:
      name: postgres-creds
      key: username
- name: POSTGRES_DB
  valueFrom:
    secretKeyRef:
      name: postgres-creds
      key: database
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: postgres-creds
      key: password
```

Save and exit.

---

### Step 4: Verify rollout completed

```bash
kubectl rollout status deployment/postgres-db -n data-layer
```

---

### Step 5: Verify env vars now coming from Secret

```bash
kubectl describe deployment postgres-db -n data-layer | grep -A15 "Environment"
```

Expected output:
```
Environment:
  POSTGRES_USER:      <set to the key 'username' in secret 'postgres-creds'>
  POSTGRES_DB:        <set to the key 'database' in secret 'postgres-creds'>
  POSTGRES_PASSWORD:  <set to the key 'password' in secret 'postgres-creds'>
```

---

### Step 6: Verify postgres is still working with Secret values

```bash
# exec into pod
kubectl exec -it -n data-layer deploy/postgres-db -- \
  psql -U admin -d myappdb -c "\conninfo"
```

Expected output:
```
You are connected to database "myappdb" as user "admin" 
via socket in "/var/run/postgresql" at port "5432".
```

✅ Postgres still running correctly
✅ Values now coming from Secret not hardcoded
✅ Connection works with Secret-based credentials

</details>

---

# ↩️ Restore Cluster State

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `reset_q12_baseline.sh` | Moving to next problem? Run this to remove all Q12 changes and restore clean cluster state |

---

### 🧹 Script : reset_q12_baseline.sh

**Done with this problem? Moving to the next one?**
Run this to remove all Q12 changes and restore a clean cluster state.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q12: Move Hardcoded Secrets to a Secret
# reset_q12_baseline.sh
# ============================================================

set -euo pipefail

NAMESPACE="data-layer"

echo ""
echo "==========================================="
echo " CKAD Q12 — Restoring cluster to baseline..."
echo "==========================================="
echo ""

echo "[1/1] Deleting namespace '$NAMESPACE' (Deployment + Secret)..."
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