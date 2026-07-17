# 🧩 Problem Statement (Resource Requests, Limits & ResourceQuota)

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task; failure to do so may result in a score of **0**.

**Context:**
You need to create a Pod that requests specific amounts of CPU and memory.

**Task:**

Modify the Pods of the Deployment `nginx-resources` in the namespace `pod-resources` to:

- **Request** `30m` CPU and `38Mi` memory
- Set CPU and memory **limits** to **twice** their respective requests
- Ensure the **maximum total resources** available to the Pods of Deployment `nginx-resources` match the total resources in the namespace

</details>

---

# 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `setup_q15_problem_scenario.sh` | Deploys a ResourceQuota (30m CPU / 36Mi mem) and `nginx-resources` with no resources set — run before practice (re-run anytime to practice again) |

---

### 📥 Script : setup_q15_problem_scenario.sh

Run this **before you start practicing** this problem.
Re-run anytime you want to practice again after fixing.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q15: Resource Requests, Limits & ResourceQuota
# setup_q15_problem_scenario.sh
# Deploys ResourceQuota (30m/36Mi) + nginx-resources with no
# resources set — pods fail quota validation until fixed
# Run on: controlplane node
# ============================================================

set -euo pipefail

NAMESPACE="pod-resources"
DEPLOYMENT="nginx-resources"

echo ""
echo "==========================================="
echo " CKAD Q15 — Setting up ResourceQuota scenario..."
echo "==========================================="
echo ""

# ── Step 0: Revert solution-specific changes (fast) ────────────
# Only undoes what THIS question's solution changes:
# - Deployment resources (solution adds requests/limits)
# - ResourceQuota hard limits (solution raises them to 60m/76Mi)
# Both are re-applied to their original scenario state below.
echo "[0/4] Reverting any previous solution changes..."
kubectl delete deployment "$DEPLOYMENT" -n "$NAMESPACE" --ignore-not-found
echo "  Reverted (Deployment removed; recreated without resources below)."

# ── Step 1: Create the namespace ───────────────────────────────
echo "[1/4] Ensuring namespace '$NAMESPACE' exists..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo "  Namespace ready."

# ── Step 2: Create/reset the ResourceQuota (intentionally low) ──
echo "[2/4] Applying ResourceQuota (limits.cpu=30m, limits.memory=36Mi)..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: pod-resources-quota
  namespace: $NAMESPACE
spec:
  hard:
    limits.cpu: "30m"
    limits.memory: "36Mi"
EOF
echo "  ResourceQuota applied."

# ── Step 3: Create the Deployment without resource requests/limits ──
echo "[3/4] Creating $DEPLOYMENT (no resources set)..."

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
      app: nginx-resources
  template:
    metadata:
      labels:
        app: nginx-resources
    spec:
      containers:
      - name: nginx-resources
        image: devopstechtales/ckad-exam-questions:1.15.7
        command:
        - sh
        - -c
        - while true; do echo 'Running'; sleep 10; done
EOF
echo "  Applied (intentionally broken — no resources set)."

# ── Step 4: Verify pods are failing ─────────────────────────────
echo "[4/4] Verifying scenario is broken..."
sleep 3
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE"
kubectl describe ns "$NAMESPACE"
echo "  ReplicaSet error (expect quota validation failure):"
kubectl describe replicaset -n "$NAMESPACE" 2>/dev/null | grep -A5 "Error" || true

echo ""
echo "✅ Q15 scenario is ready!"
echo ""
echo "   nginx-resources cannot schedule — no cpu/memory limits set,"
echo "   and the namespace ResourceQuota requires them."
echo "   Now go fix it! 💪"
echo ""
```

</details>

---

# ✅ Solution

<details>
<summary>Click to expand the solution</summary>

---

### Step 1: Check existing ResourceQuota on namespace

```bash
kubectl describe ns pod-resources
```

Output:
```
Resource Quotas
  Name: pod-resources-quota
  Resource       Used  Hard
  --------       ----  ----
  limits.cpu     0     30m
  limits.memory  0     36Mi

No LimitRange resource.
```

---

### Step 2: Calculate required values

```
Given in task:
  requests.cpu    = 30m
  requests.memory = 38Mi

Limits = 2x requests:
  limits.cpu    = 30m × 2 = 60m
  limits.memory = 38Mi × 2 = 76Mi

Existing RQ hard limits:
  limits.cpu    = 30m   ❌ too low for pod limit of 60m
  limits.memory = 36Mi  ❌ too low for pod limit of 76Mi
→ RQ needs to be updated after setting pod resources
```

---

### Step 3: Update Deployment with resource requests and limits

```bash
kubectl edit deployment nginx-resources -n pod-resources
```

Add resources section under container:

```yaml
spec:
  template:
    spec:
      containers:
      - name: nginx-resources
        image: devopstechtales/ckad-exam-questions:1.15.7
        resources:
          requests:
            cpu: "30m"       # ✅ as specified in task
            memory: "38Mi"   # ✅ as specified in task
          limits:
            cpu: "60m"       # ✅ 2x request
            memory: "76Mi"   # ✅ 2x request
```

Save and exit.

---

### Step 4: Check pods — still failing due to RQ

```bash
kubectl get pods -n pod-resources
```

```
NAME                            READY   STATUS
nginx-resources-xxx-xxx         0/1     Pending   ❌ still failing!
```

```bash
kubectl describe replicaset -n pod-resources | grep Error
```

Output:
```
Error: exceeded quota: pod-resources-quota
  limited: limits.cpu=30m, limits.memory=36Mi
```

> RQ hard limits are too low — pod needs 60m cpu and 76Mi memory but RQ only allows 30m and 36Mi!

---

### Step 5: Update ResourceQuota to match pod limits

```bash
kubectl edit resourcequota pod-resources-quota -n pod-resources
```

Update hard limits to match pod limits exactly:

```yaml
spec:
  hard:
    limits.cpu: "60m"      # ✅ updated to match pod limit cpu
    limits.memory: "76Mi"  # ✅ updated to match pod limit memory
```

Save and exit.

---

### Step 6: Verify pods are now running

```bash
kubectl get deployment nginx-resources -n pod-resources
kubectl get pods -n pod-resources
```

Expected:
```
NAME               READY   UP-TO-DATE   AVAILABLE
nginx-resources    1/1     1            1          ✅
```

---

### Step 7: Verify ResourceQuota usage matches hard limits

```bash
kubectl describe ns pod-resources
```

Expected output:
```
Resource Quotas
  Name: pod-resources-quota
  Resource       Used   Hard
  --------       ----   ----
  limits.cpu     60m    60m    ✅ used = hard (exactly matches)
  limits.memory  76Mi   76Mi   ✅ used = hard (exactly matches)
```

---

### Step 8: Verify resource settings on pod

```bash
kubectl describe pod -n pod-resources | grep -A8 "Limits"
```

Expected:
```
Limits:
  cpu:     60m
  memory:  76Mi
Requests:
  cpu:     30m
  memory:  38Mi
```

</details>

---

# ↩️ Restore Cluster State

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `reset_q15_baseline.sh` | Moving to next problem? Run this to remove all Q15 changes and restore clean cluster state |

---

### 🧹 Script : reset_q15_baseline.sh

**Done with this problem? Moving to the next one?**
Run this to remove all Q15 changes and restore a clean cluster state.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q15: Resource Requests, Limits & ResourceQuota
# reset_q15_baseline.sh
# ============================================================

set -euo pipefail

NAMESPACE="pod-resources"

echo ""
echo "==========================================="
echo " CKAD Q15 — Restoring cluster to baseline..."
echo "==========================================="
echo ""

echo "[1/1] Deleting namespace '$NAMESPACE' (Deployment + ResourceQuota)..."
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