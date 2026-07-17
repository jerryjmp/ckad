# 🧩 Problem Statement (Add Readiness Probe)

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task; failure to do so may result in a score of **0**.

**Task:**

A Deployment named `web-probe` in the namespace `staging-ops` runs a web application on port `80`. Modify the Deployment to add a **readiness probe** with the following configuration:

- Path: `/healthz/return200`
- `initialDelaySeconds`: `15`
- `periodSeconds`: `20`

</details>

---

# 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `setup_q10_problem_scenario.sh` | Deploys `web-probe` with no readiness probe configured — run before practice (re-run anytime to practice again) |

---

### 📥 Script : setup_q10_problem_scenario.sh

Run this **before you start practicing** this problem.
Re-run anytime you want to practice again after fixing.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q10: Add Readiness Probe
# setup_q10_problem_scenario.sh
# Deploys web-probe with no readinessProbe set
# Run on: controlplane node
# ============================================================

set -euo pipefail

NAMESPACE="staging-ops"
DEPLOYMENT="web-probe"

echo ""
echo "==========================================="
echo " CKAD Q10 — Setting up Readiness Probe scenario..."
echo "==========================================="
echo ""

# ── Step 0: Revert solution-specific changes (fast) ────────────
# Only undoes what THIS question's solution changes:
# - the readinessProbe added to the container spec
echo "[0/3] Reverting any previous solution changes..."
if kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" &>/dev/null; then
  kubectl patch deployment "$DEPLOYMENT" -n "$NAMESPACE" \
    --type=json \
    -p='[{"op":"remove","path":"/spec/template/spec/containers/0/readinessProbe"}]' 2>/dev/null || true
fi
echo "  Reverted."

# ── Step 1: Create the namespace ───────────────────────────────
echo "[1/3] Ensuring namespace '$NAMESPACE' exists..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo "  Namespace ready."

# ── Step 2: Create the Deployment without a readiness probe ────
echo "[2/3] Creating $DEPLOYMENT Deployment (no readiness probe)..."

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $DEPLOYMENT
  namespace: $NAMESPACE
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-probe
  template:
    metadata:
      labels:
        app: web-probe
    spec:
      containers:
      - name: web-probe
        image: devopstechtales/ckad-exam-questions:readiness-probe
        ports:
        - containerPort: 80
EOF

echo "  Waiting for pods to be Ready..."
kubectl wait --for=condition=ready pod -l app=web-probe -n "$NAMESPACE" --timeout=120s
echo "  Pods Ready."

# ── Step 3: Verify no readiness probe configured yet ────────────
echo "[3/3] Verifying resources..."
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE"
echo "  Readiness probe check (should be empty):"
kubectl describe deployment "$DEPLOYMENT" -n "$NAMESPACE" | grep -i readiness || echo "  (none configured, as expected)"

echo ""
echo "✅ Q10 scenario is ready!"
echo ""
echo "   $DEPLOYMENT is running with no readiness probe."
echo "   Now go fix it! 💪"
echo ""
```

</details>

---

# ✅ Solution

<details>
<summary>Click to expand the solution</summary>

---

### Step 1: Edit the Deployment

```bash
kubectl edit deployment web-probe -n staging-ops
```

Find the `containers` section and add `readinessProbe`:

```yaml
spec:
  template:
    spec:
      containers:
      - name: web-probe
        image: devopstechtales/ckad-exam-questions:readiness-probe
        ports:
        - containerPort: 80
        readinessProbe:             # ✅ add from here
          httpGet:
            path: /healthz/return200
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 20         # ✅ to here
```

Save and exit.

---

### Step 2: Verify rollout

```bash
kubectl rollout status deployment/web-probe -n staging-ops
```

---

### Step 3: Verify readiness probe is configured

```bash
kubectl describe deployment web-probe -n staging-ops | grep -A8 "Readiness"
```

Expected output:
```
Readiness:  http-get http://:80/healthz/return200
            delay=15s
            period=20s
            success=1
            failure=3
```

---

### Step 4: Verify pods are Ready

```bash
kubectl get pods -n staging-ops
```

Expected:
```
NAME                        READY   STATUS    RESTARTS
web-probe-xxx-xxx           1/1     Running   0
web-probe-xxx-xxx           1/1     Running   0
```

> `1/1` means pod passed readiness probe and is ready to receive traffic ✅

</details>

---

# ↩️ Restore Cluster State

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `reset_q10_baseline.sh` | Moving to next problem? Run this to remove all Q10 changes and restore clean cluster state |

---

### 🧹 Script : reset_q10_baseline.sh

**Done with this problem? Moving to the next one?**
Run this to remove all Q10 changes and restore a clean cluster state.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q10: Add Readiness Probe
# reset_q10_baseline.sh
# ============================================================

set -euo pipefail

NAMESPACE="staging-ops"

echo ""
echo "==========================================="
echo " CKAD Q10 — Restoring cluster to baseline..."
echo "==========================================="
echo ""

echo "[1/1] Deleting namespace '$NAMESPACE' (Deployment)..."
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