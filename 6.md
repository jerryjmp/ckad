# 🧩 Problem Statement (Upgrade and Rollback)

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task.

**Task:**

1. Update the **rolling update strategy** of the Deployment `nginx-frontend` in the namespace `webteam` — set `maxSurge` to `5%` and `maxUnavailable` to `5%`.

2. Update the Deployment `nginx-frontend` to use the container image `devopstechtales/ckad-exam-questions:1.15.7`.

3. **Roll back** the Deployment `nginx-frontend` to its **previous version**.

</details>

---

# 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `setup_q06_problem_scenario.sh` | Creates the `webteam` namespace and `nginx-frontend` Deployment on the old image — run before practice (re-run anytime to practice again) |

---

### 📥 Script : setup_q06_problem_scenario.sh

Run this **before you start practicing** this problem.
Re-run anytime you want to practice again after fixing.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q06: Upgrade and Rollback
# setup_q06_problem_scenario.sh
# Deploys nginx-frontend on image 1.14.7, no custom strategy,
# no rollout history — clean slate for the rollout/rollback task
# Run on: controlplane node
# ============================================================

set -euo pipefail

NAMESPACE="webteam"
DEPLOYMENT="nginx-frontend"
OLD_IMAGE="devopstechtales/ckad-exam-questions:1.14.7"

echo ""
echo "==========================================="
echo " CKAD Q06 — Setting up Upgrade/Rollback scenario..."
echo "==========================================="
echo ""

# ── Step 0: Revert solution-specific changes (fast) ────────────
# The task itself is about mutating strategy, image, and rollout
# history — all of which live inside the Deployment object and
# its ReplicaSet history. The only reliable way to reset all of
# that (strategy patch + image + revisions) is to delete and
# recreate the Deployment fresh — this is fast since it's a
# single object, not a full namespace teardown.
echo "[0/3] Reverting any previous solution changes..."
kubectl delete deployment "$DEPLOYMENT" -n "$NAMESPACE" --ignore-not-found
echo "  Reverted."

# ── Step 1: Create the namespace ───────────────────────────────
echo "[1/3] Ensuring namespace '$NAMESPACE' exists..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo "  Namespace ready."

# ── Step 2: Create the Deployment on the old image ─────────────
echo "[2/3] Creating $DEPLOYMENT on $OLD_IMAGE..."
kubectl create deployment "$DEPLOYMENT" \
  --image="$OLD_IMAGE" \
  --namespace="$NAMESPACE" \
  --replicas=1

echo "  Waiting for pod to be Ready..."
kubectl wait --for=condition=ready pod -l app="$DEPLOYMENT" -n "$NAMESPACE" --timeout=120s
echo "  Pod Ready."

# ── Step 3: Verify ────────────────────────────────────────────────
echo "[3/3] Verifying resources..."
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE"
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'

echo ""
echo "✅ Q06 scenario is ready!"
echo ""
echo "   $DEPLOYMENT is running on $OLD_IMAGE"
echo "   No custom rolling update strategy set. No rollout history yet."
echo "   Now go fix it! 💪"
echo ""
```

</details>

---

# ✅ Solution

<details>
<summary>Click to expand the solution</summary>

---

### Task 1: Update the Rolling Update Strategy

Edit the deployment:

```bash
kubectl edit deployment nginx-frontend -n webteam
```

Under `spec.strategy`, update or add the following:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 5%
    maxUnavailable: 5%
```

Save and exit.

Or use patch command directly:

```bash
kubectl patch deployment nginx-frontend -n webteam \
  -p '{"spec":{"strategy":{"type":"RollingUpdate","rollingUpdate":{"maxSurge":"5%","maxUnavailable":"5%"}}}}'
```

**Verify:**

```bash
kubectl describe deployment nginx-frontend -n webteam | grep -A3 "RollingUpdateStrategy"
```

---

### Task 2: Update the Image Version

```bash
kubectl set image deployment/nginx-frontend \
  ckad-exam-questions=devopstechtales/ckad-exam-questions:1.15.7 \
  -n webteam \
  --record
```

> ⚠️ `--record` saves this command in the rollout history, which is needed for Task 3.

**Verify the rollout:**

```bash
kubectl rollout status deployment/nginx-frontend -n webteam
```

**Check rollout history:**

```bash
kubectl rollout history deployment/nginx-frontend -n webteam
```

You should see **2 revisions** — revision 1 (old image) and revision 2 (new image).

---

### Task 3: Roll Back to Previous Version

```bash
kubectl rollout undo deployment/nginx-frontend -n webteam
```

**Verify the rollback:**

```bash
kubectl rollout status deployment/nginx-frontend -n webteam
kubectl describe deployment nginx-frontend -n webteam | grep Image
```

Image should now show `devopstechtales/ckad-exam-questions:1.14.7` again. ✅

</details>

---

# ↩️ Restore Cluster State

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `reset_q06_baseline.sh` | Moving to next problem? Run this to remove all Q06 changes and restore clean cluster state |

---

### 🧹 Script : reset_q06_baseline.sh

**Done with this problem? Moving to the next one?**
Run this to remove all Q06 changes and restore a clean cluster state.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q06: Upgrade and Rollback
# reset_q06_baseline.sh
# ============================================================

set -euo pipefail

NAMESPACE="webteam"

echo ""
echo "==========================================="
echo " CKAD Q06 — Restoring cluster to baseline..."
echo "==========================================="
echo ""

echo "[1/1] Deleting namespace '$NAMESPACE' (Deployment + ReplicaSets)..."
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