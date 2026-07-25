# 🧩 Problem Statement (Scale, Label & Expose Deployment)

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task; failure to do so may result in a score of **0**.

**Task:**

1. Update the Deployment `web-frontend` in the namespace `app-team`:
   - Scale it to run **3 Pod replicas**
   - Add the label `tier: proxy` to the **Pods**

2. Create a **NodePort Service** named `gateway` in the namespace `app-team` to expose the Deployment `web-frontend` on TCP port `81`

</details>

---

# 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `setup_q08_problem_scenario.sh` | Deploys `web-frontend` with 1 replica, no `tier` label, no Service — run before practice (re-run anytime to practice again) |

---

### 📥 Script : setup_q08_problem_scenario.sh

Run this **before you start practicing** this problem.
Re-run anytime you want to practice again after fixing.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q08: Scale, Label & Expose Deployment
# setup_q08_problem_scenario.sh
# Deploys web-frontend (1 replica, no tier label), no Service
# Run on: controlplane node
# ============================================================

set -euo pipefail

NAMESPACE="app-team"
DEPLOYMENT="web-frontend"

echo ""
echo "==========================================="
echo " CKAD Q08 — Setting up Scale/Label/Expose scenario..."
echo "==========================================="
echo ""

# ── Step 0: Revert solution-specific changes (fast) ────────────
# Only undoes what THIS question's solution changes:
# - replica count (scaled to 3 by solution → back to 1)
# - tier: proxy label on the pod template (added by solution → removed)
# - gateway Service (created by solution → deleted)
echo "[0/3] Reverting any previous solution changes..."
kubectl delete service gateway -n "$NAMESPACE" --ignore-not-found
if kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" &>/dev/null; then
  kubectl scale deployment "$DEPLOYMENT" -n "$NAMESPACE" --replicas=1
  kubectl patch deployment "$DEPLOYMENT" -n "$NAMESPACE" \
    --type=json \
    -p='[{"op":"remove","path":"/spec/template/metadata/labels/tier"}]' 2>/dev/null || true
fi
echo "  Reverted."

# ── Step 1: Create the namespace ───────────────────────────────
echo "[1/3] Ensuring namespace '$NAMESPACE' exists..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo "  Namespace ready."

# ── Step 2: Create the Deployment ───────────────────────────────
echo "[2/3] Creating $DEPLOYMENT Deployment (1 replica)..."

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
      app: web-frontend
  template:
    metadata:
      labels:
        app: web-frontend
    spec:
      containers:
      - name: web-frontend
        image: devopstechtales/ckad-exam-questions:1.15.7
        command:
        - sh
        - -c
        - while true; do echo 'Web Frontend Running'; sleep 10; done
        ports:
        - containerPort: 81
EOF

echo "  Waiting for pod to be Ready..."
kubectl wait --for=condition=ready pod -l app=web-frontend -n "$NAMESPACE" --timeout=120s
echo "  Pod Ready."

# ── Step 3: Verify ────────────────────────────────────────────────
echo "[3/3] Verifying resources..."
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE"
kubectl get pods -n "$NAMESPACE" --show-labels

echo ""
echo "✅ Q08 scenario is ready!"
echo ""
echo "   $DEPLOYMENT running with 1 replica, no tier label, no Service."
echo "   Now go fix it! 💪"
echo ""
```

</details>

---

# ✅ Solution

<details>
<summary>Click to expand the solution</summary>

---

### Step 1: Scale Deployment to 3 replicas

```bash
kubectl scale deployment web-frontend \
  --replicas=3 \
  -n app-team
```

**Verify:**

```bash
kubectl get deployment web-frontend -n app-team
```

Expected:
```
NAME           READY   UP-TO-DATE   AVAILABLE
web-frontend   3/3     3            3
```

---

### Step 2: Add label tier: proxy to the Pods

This means adding the label to the **Pod template** inside the Deployment — not just the pods directly.

```bash
kubectl edit deployment web-frontend -n app-team
```

Find the `template.metadata.labels` section and add `tier: proxy`:

```yaml
spec:
  template:
    metadata:
      labels:
        app: web-frontend
        tier: proxy          # ✅ add this line
```

Save and exit — this triggers a rollout automatically.

Or use patch command directly:

```bash
kubectl patch deployment web-frontend -n app-team \
  --type=json \
  -p='[{"op":"add","path":"/spec/template/metadata/labels/tier","value":"proxy"}]'
```

**Verify pods have new label:**

```bash
kubectl get pods -n app-team --show-labels
```

Expected:
```
NAME                          LABELS
web-frontend-xxx-xxx   app=web-frontend,tier=proxy
web-frontend-xxx-xxx   app=web-frontend,tier=proxy
web-frontend-xxx-xxx   app=web-frontend,tier=proxy
```

---

### Step 3: Create NodePort Service

```bash
kubectl expose deployment web-frontend \
  --name=gateway \
  --type=NodePort \
  --port=81 \
  --target-port=81 \
  --namespace=app-team
```

---

### Step 4: Verify Service and Endpoints

```bash
kubectl get svc gateway -n app-team
```

Expected:
```
NAME      TYPE       CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
gateway   NodePort   10.96.x.x     <none>        81:3XXXX/TCP   10s
```

```bash
kubectl get endpoints gateway -n app-team
```

You should see **3 pod IPs** listed — one for each replica. ✅

</details>

---

# ↩️ Restore Cluster State

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `reset_q08_baseline.sh` | Moving to next problem? Run this to remove all Q08 changes and restore clean cluster state |

---

### 🧹 Script : reset_q08_baseline.sh

**Done with this problem? Moving to the next one?**
Run this to remove all Q08 changes and restore a clean cluster state.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q08: Scale, Label & Expose Deployment
# reset_q08_baseline.sh
# ============================================================

set -euo pipefail

NAMESPACE="app-team"

echo ""
echo "==========================================="
echo " CKAD Q08 — Restoring cluster to baseline..."
echo "==========================================="
echo ""

echo "[1/1] Deleting namespace '$NAMESPACE' (Deployment + Service)..."
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
