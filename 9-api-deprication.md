# 🧩 Problem Statement (Fix Deprecated API & Deploy)

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task; failure to do so may result in a score of **0**.

**Context:**
You need to deploy an application developed for an older version of Kubernetes on a cluster running the latest Kubernetes version.

**Task:**

1. Fix any **API deprecation issues** in the manifest file `/ckad/legacy-app/app.yaml` so the application can be deployed on the Kubernetes cluster.
   > Note: The application was developed for **Kubernetes v1.15**, while the cluster runs **Kubernetes v1.35**.

2. Deploy the application specified in the updated manifest file `/ckad/legacy-app/app.yaml` in the namespace `sandstone`.

</details>

---

# 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `setup_q09_problem_scenario.sh` | Writes the deprecated-API manifest file, confirms `apply` fails — run before practice (re-run anytime to practice again) |

---

### 📥 Script : setup_q09_problem_scenario.sh

Run this **before you start practicing** this problem.
Re-run anytime you want to practice again after fixing.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q09: Fix Deprecated API & Deploy
# setup_q09_problem_scenario.sh
# Writes app.yaml with extensions/v1beta1 apiVersion (invalid on
# this cluster) — nothing gets deployed until the user fixes it
# Run on: controlplane node
# ============================================================

set -euo pipefail

NAMESPACE="sandstone"
MANIFEST_DIR="$HOME/ckad/legacy-app"

echo ""
echo "==========================================="
echo " CKAD Q09 — Setting up API deprecation scenario..."
echo "==========================================="
echo ""

# ── Step 0: Revert solution-specific changes (fast) ────────────
# Only undoes what THIS question's solution changes:
# - the app.yaml manifest (fixed apiVersion + selector by solution)
# - the legacy-web Deployment (created once the manifest is fixed)
echo "[0/3] Reverting any previous solution changes..."
kubectl delete deployment legacy-web -n "$NAMESPACE" --ignore-not-found
echo "  Reverted."

# ── Step 1: Create namespace and directory ─────────────────────
echo "[1/3] Ensuring namespace '$NAMESPACE' and manifest dir exist..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
mkdir -p "$MANIFEST_DIR"
echo "  Ready."

# ── Step 2: Write the manifest with deprecated API ──────────────
echo "[2/3] Writing app.yaml with deprecated apiVersion..."

cat <<EOF > "$MANIFEST_DIR/app.yaml"
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: legacy-web
  namespace: $NAMESPACE
spec:
  replicas: 2
  template:
    metadata:
      labels:
        app: legacy-web
    spec:
      containers:
      - name: legacy-web
        image: devopstechtales/ckad-exam-questions:1.15.7
        command:
        - sh
        - -c
        - while true; do echo 'Legacy App Running'; sleep 10; done
        ports:
        - containerPort: 80
EOF
echo "  Manifest written."

# ── Step 3: Confirm apply fails as expected ─────────────────────
echo "[3/3] Verifying scenario is broken (apply should fail)..."
kubectl apply -f "$MANIFEST_DIR/app.yaml" || echo "  (as expected — apply failed due to deprecated API)"

echo ""
echo "✅ Q09 scenario is ready!"
echo ""
echo "   Manifest at: $MANIFEST_DIR/app.yaml uses extensions/v1beta1."
echo "   No legacy-web Deployment exists yet."
echo "   Now go fix it! 💪"
echo ""
```

</details>

---

# ✅ Solution

<details>
<summary>Click to expand the solution</summary>

---

### Step 1: Check the manifest file

```bash
cat ~/ckad/legacy-app/app.yaml
```

Identify the deprecated API:
```yaml
apiVersion: extensions/v1beta1    # ❌ this is the problem
kind: Deployment
```

---

### Step 2: Understand API deprecation history

| Resource | Old API (deprecated) | New API (current) |
|---|---|---|
| Deployment | `extensions/v1beta1` | `apps/v1` |
| DaemonSet | `extensions/v1beta1` | `apps/v1` |
| ReplicaSet | `extensions/v1beta1` | `apps/v1` |
| Ingress | `extensions/v1beta1` | `networking.k8s.io/v1` |
| NetworkPolicy | `extensions/v1beta1` | `networking.k8s.io/v1` |
| PodSecurityPolicy | `extensions/v1beta1` | **Removed** in v1.25 |

> In exam always check `apiVersion` first when you see a legacy manifest!

---

### Step 3: Fix the manifest

#### Fix 1: Update apiVersion:

```bash
vim ~/ckad/legacy-app/app.yaml
```

Change:
```yaml
apiVersion: extensions/v1beta1    # ❌ old
```

To:
```yaml
apiVersion: apps/v1               # ✅ current
```

#### Fix 2: Add selector field (mandatory in apps/v1)

```yaml
spec:
  replicas: 2
  selector:               # ✅ must add this — required in apps/v1
    matchLabels:
      app: legacy-web     # must match template.metadata.labels exactly
  template:
    metadata:
      labels:
        app: legacy-web
```

Full corrected file:

```yaml
apiVersion: apps/v1               # ✅ Fix 1: updated apiVersion
kind: Deployment
metadata:
  name: legacy-web
  namespace: sandstone
spec:
  replicas: 2
  selector:                       # ✅ Fix 2: added mandatory selector
    matchLabels:
      app: legacy-web
  template:
    metadata:
      labels:
        app: legacy-web
    spec:
      containers:
      - name: legacy-web
        image: devopstechtales/ckad-exam-questions:1.15.7
        command:
        - sh
        - -c
        - while true; do echo 'Legacy App Running'; sleep 10; done
        ports:
        - containerPort: 80
```

---

### Step 4: Deploy the application

```bash
kubectl apply -f ~/ckad/legacy-app/app.yaml
```

Expected output:
```
deployment.apps/legacy-web created
```

---

### Step 5: Verify deployment

```bash
kubectl get deployment legacy-web -n sandstone
kubectl get pods -n sandstone
```

Expected:
```
NAME         READY   UP-TO-DATE   AVAILABLE
legacy-web   2/2     2            2
```

✅ API deprecation fixed
✅ selector → add matchLabels matching pod template labels
✅ Application deployed successfully in `sandstone` namespace

---

### How to quickly find deprecated APIs in exam:

```bash
# check what apiVersion is valid for a resource
kubectl explain deployment | head -5

# output shows:
# VERSION: apps/v1   ← this is the correct current apiVersion
```

> `kubectl explain` is your best friend for API version checks in exam! ✅

</details>

---

# ↩️ Restore Cluster State

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `reset_q09_baseline.sh` | Moving to next problem? Run this to remove all Q09 changes and restore clean cluster state |

---

### 🧹 Script : reset_q09_baseline.sh

**Done with this problem? Moving to the next one?**
Run this to remove all Q09 changes and restore a clean cluster state.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q09: Fix Deprecated API & Deploy
# reset_q09_baseline.sh
# ============================================================

set -euo pipefail

NAMESPACE="sandstone"
MANIFEST_DIR="$HOME/ckad/legacy-app"

echo ""
echo "==========================================="
echo " CKAD Q09 — Restoring cluster to baseline..."
echo "==========================================="
echo ""

echo "[1/2] Deleting namespace '$NAMESPACE' (Deployment)..."
kubectl delete namespace "$NAMESPACE" --ignore-not-found
echo "  Waiting for namespace deletion to complete..."
while kubectl get namespace "$NAMESPACE" &>/dev/null; do
  sleep 2
done
echo "  Namespace removed."

echo "[2/2] Removing manifest directory..."
rm -rf "$MANIFEST_DIR"
echo "  Manifest directory removed."

echo ""
echo "✅ Cluster is back to baseline!"
echo ""
echo "   Safe to move to next problem. 🚀"
echo ""
```

</details>

---