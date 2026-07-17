# 🧩 Problem Statement (Modify Container Name and Image on a Paused Deployment)

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task.

**Task:**

Update the existing Deployment `alpine-runner` running in the namespace `rapid-fire`. **Do NOT delete the existing Deployment**, as this will result in a score of 0.

1. Change the **container name** to `core`.
2. Change the **container image** to `devopstechtales/ckad-exam-questions:core`.
3. Ensure the changes to the Deployment `alpine-runner` in the namespace `rapid-fire` are **successfully applied**.

</details>

---

# 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `setup_q17_problem_scenario.sh` | Deploys `alpine-runner` (container `fun`, image `:fun`) and pauses it — run before practice (re-run anytime to practice again) |

---

### 📥 Script : setup_q17_problem_scenario.sh

Run this **before you start practicing** this problem.
Re-run anytime you want to practice again after fixing.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q17: Modify Container Name and Image (Paused Deployment)
# setup_q17_problem_scenario.sh
# Deploys alpine-runner (container "fun", image ":fun"), then
# pauses the Deployment to simulate the exam condition
# Run on: controlplane node
# ============================================================

set -euo pipefail

NAMESPACE="rapid-fire"
DEPLOYMENT="alpine-runner"

echo ""
echo "==========================================="
echo " CKAD Q17 — Setting up Paused Deployment scenario..."
echo "==========================================="
echo ""

# ── Step 0: Revert solution-specific changes (fast) ────────────
# Only undoes what THIS question's solution changes:
# - container name (core → back to fun)
# - container image (:core → back to :fun)
# - paused field (false → back to true)
# Re-applying the original Deployment below handles the container
# name/image revert; the paused patch is re-applied separately
# since `paused` lives outside the pod template and isn't touched
# by a template-only apply.
echo "[0/1] Reverting any previous solution changes..."
echo "  (handled by Steps 1–3 below — apply + re-pause)"

# ── Step 1: Create the namespace ───────────────────────────────
echo "[1/3] Ensuring namespace '$NAMESPACE' exists..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo "  Namespace ready."

# ── Step 2: Create/reset the Deployment (container: fun, image: :fun) ──
echo "[2/3] Applying $DEPLOYMENT (container 'fun', image ':fun')..."

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
      app: alpine-runner
  template:
    metadata:
      labels:
        app: alpine-runner
    spec:
      containers:
      - name: fun
        image: devopstechtales/ckad-exam-questions:fun
        command:
        - sh
        - -c
        - while true; do echo 'Container Running'; sleep 600; done
        imagePullPolicy: IfNotPresent
EOF

sleep 5
echo "  Waiting for pod to be Ready..."
kubectl wait --for=condition=ready pod -l app=alpine-runner -n "$NAMESPACE" --timeout=120s
echo "  Pod Ready."

# ── Step 3: Pause the Deployment to simulate exam condition ────
echo "[3/3] Pausing $DEPLOYMENT..."
kubectl patch deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -p '{"spec":{"paused": true}}'

echo "  Verifying..."
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE"
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.paused}{"\n"}'

echo ""
echo "✅ Q17 scenario is ready!"
echo ""
echo "   $DEPLOYMENT is running (container: fun, image: :fun) and PAUSED."
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
kubectl edit deployment alpine-runner -n rapid-fire
```

Inside the editor, find the `containers` section:

```yaml
spec:
  template:
    spec:
      containers:
      - name: fun    # change this to core
        image: devopstechtales/ckad-exam-questions:fun  # change version to core
```

Change it to:

```yaml
spec:
  template:
    spec:
      containers:
      - name: core                                        # ✅ container name changed
        image: devopstechtales/ckad-exam-questions:core   # ✅ image tag changed
```

Also find the `paused` field and either **remove it** or set it to `false`:

```yaml
spec:
  paused: false    # ✅ unpause to trigger rollout
```

Save and exit.

---

### Step 2: Verify rollout triggered

```bash
kubectl rollout status deployment/alpine-runner -n rapid-fire
```

Expected output:
```
deployment "alpine-runner" successfully rolled out
```

---

### Step 3: Confirm changes applied

```bash
kubectl describe deployment alpine-runner -n rapid-fire | grep -E "Name:|Image:"
```

Expected output:
```
Name:         core
Image:        devopstechtales/ckad-exam-questions:core
```

Or check via:

```bash
kubectl get deployment alpine-runner -n rapid-fire -o jsonpath=\
'{.spec.template.spec.containers[*].name}'
```

```bash
kubectl get deployment alpine-runner -n rapid-fire -o jsonpath=\
'{.spec.template.spec.containers[*].image}'
```

</details>

---

# ↩️ Restore Cluster State

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `reset_q17_baseline.sh` | Moving to next problem? Run this to remove all Q17 changes and restore clean cluster state |

---

### 🧹 Script : reset_q17_baseline.sh

**Done with this problem? Moving to the next one?**
Run this to remove all Q17 changes and restore a clean cluster state.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q17: Modify Container Name and Image (Paused Deployment)
# reset_q17_baseline.sh
# ============================================================

set -euo pipefail

NAMESPACE="rapid-fire"

echo ""
echo "==========================================="
echo " CKAD Q17 — Restoring cluster to baseline..."
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