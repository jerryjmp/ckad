# 🧩 Problem Statement (Fix LimitRange Memory Violation)

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task; failure to do so may result in a score of **0**.

**Task:**

Pods of the Deployment `cache-db` in the namespace `ironclad` fail to start because their containers have exhausted resources. Update the `cache-db` Deployment so the Pods:

- **Request** `15Mi` of memory for their containers
- Set the memory **limit** to **half of the maximum memory capacity** configured for the `ironclad` namespace

The configuration manifest for the `cache-db` Deployment can be found at `/ckad/ironclad-ops/cache-db.yaml`

</details>

---

# 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `setup_q13_problem_scenario.sh` | Deploys a LimitRange (max 60Mi) and `cache-db` with memory requests/limits that exceed it — run before practice (re-run anytime to practice again) |

---

### 📥 Script : setup_q13_problem_scenario.sh

Run this **before you start practicing** this problem.
Re-run anytime you want to practice again after fixing.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q13: Fix LimitRange Memory Violation
# setup_q13_problem_scenario.sh
# Deploys LimitRange (max 60Mi) + cache-db requesting 50Mi/80Mi
# (exceeds max) — pods fail to start until fixed
# Run on: controlplane node
# ============================================================

set -euo pipefail

NAMESPACE="ironclad"
MANIFEST_DIR="$HOME/ckad/ironclad-ops"

echo ""
echo "==========================================="
echo " CKAD Q13 — Setting up LimitRange scenario..."
echo "==========================================="
echo ""

# ── Step 0: Revert solution-specific changes (fast) ────────────
# Only undoes what THIS question's solution changes: the
# cache-db manifest file (fixed memory values by solution).
echo "[0/4] Reverting any previous solution changes..."
mkdir -p "$MANIFEST_DIR"

cat <<EOF > "$MANIFEST_DIR/cache-db.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cache-db
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cache-db
  template:
    metadata:
      labels:
        app: cache-db
    spec:
      containers:
      - name: cache-db
        image: devopstechtales/ckad-exam-questions:1.15.7
        command:
        - sh
        - -c
        - while true; do echo 'Cache Running'; sleep 10; done
        resources:
          requests:
            memory: "50Mi"
          limits:
            memory: "80Mi"
EOF

if kubectl get namespace "$NAMESPACE" &>/dev/null; then
  kubectl apply -f "$MANIFEST_DIR/cache-db.yaml"
fi
echo "  Reverted to broken state."

# ── Step 1: Create the namespace ───────────────────────────────
echo "[1/4] Ensuring namespace '$NAMESPACE' exists..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo "  Namespace ready."

# ── Step 2: Create the LimitRange ───────────────────────────────
echo "[2/4] Applying LimitRange (max memory 60Mi)..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: LimitRange
metadata:
  name: ironclad-limits
  namespace: $NAMESPACE
spec:
  limits:
  - type: Container
    max:
      memory: "60Mi"
    defaultRequest:
      memory: "8Mi"
    default:
      memory: "16Mi"
EOF
echo "  LimitRange applied."

# ── Step 3: Apply the broken Deployment ─────────────────────────
echo "[3/4] Applying cache-db (memory requests/limits exceed max)..."
kubectl apply -f "$MANIFEST_DIR/cache-db.yaml"
echo "  Applied (intentionally broken)."

# ── Step 4: Verify pods are failing ─────────────────────────────
echo "[4/4] Verifying scenario is broken..."
sleep 3
kubectl get deployment cache-db -n "$NAMESPACE"
kubectl get pods -n "$NAMESPACE"
echo "  Recent events (expect memory limit error):"
kubectl describe pod -n "$NAMESPACE" 2>/dev/null | grep -A5 "Events" || true

echo ""
echo "✅ Q13 scenario is ready!"
echo ""
echo "   cache-db Deployment cannot schedule pods — requests/limits"
echo "   exceed the namespace LimitRange max of 60Mi."
echo "   Manifest at: $MANIFEST_DIR/cache-db.yaml"
echo "   Now go fix it! 💪"
echo ""
```

</details>

---

# ✅ Solution

<details>
<summary>Click to expand the solution</summary>

---

### Step 1: Check why pods are failing

```bash
kubectl get deployment cache-db -n ironclad
```

Output:
```
NAME       READY   UP-TO-DATE   AVAILABLE
cache-db   0/1     0            0          ← pods not starting!
```


---

### Step 2: Check namespace memory limits

```bash
kubectl describe ns ironclad
```

Output:
```
Resource Limits
Type       Resource  Min  Max   Default Request  Default Limit
----       --------  ---  ---   ---------------  -------------
Container  memory    -    60Mi  8Mi              16Mi
```

Key information:
- **Max memory** = `60Mi`
- Memory limit for pod = **half of max** = `60Mi / 2` = `30Mi`
- Memory request = `15Mi` (given in task)

---

### Step 3: Check the manifest file

```bash
cat ~/ckad/ironclad-ops/cache-db.yaml
```

Identify the problem:
```yaml
resources:
  requests:
    memory: "50Mi"    # ❌ exceeds namespace max of 60Mi
  limits:
    memory: "80Mi"    # ❌ exceeds namespace max of 60Mi
```

---

### Step 4: Fix the manifest

```bash
vim ~/ckad/ironclad-ops/cache-db.yaml
```

Update the resources section:

```yaml
resources:
  requests:
    memory: "15Mi"    # ✅ as specified in task
  limits:
    memory: "30Mi"    # ✅ half of 60Mi max = 30Mi
```

Full corrected file:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cache-db
  namespace: ironclad
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cache-db
  template:
    metadata:
      labels:
        app: cache-db
    spec:
      containers:
      - name: cache-db
        image: devopstechtales/ckad-exam-questions:1.15.7
        command:
        - sh
        - -c
        - while true; do echo 'Cache Running'; sleep 10; done
        resources:
          requests:
            memory: "15Mi"    # ✅ fixed
          limits:
            memory: "30Mi"    # ✅ fixed - half of 60Mi
```

---

### Step 5: Apply the fixed manifest

```bash
kubectl apply -f ~/ckad/ironclad-ops/cache-db.yaml
```

---

### Step 6: Verify pods are now running

```bash
kubectl get deployment cache-db -n ironclad
kubectl get pods -n ironclad
```

Expected:
```
NAME       READY   UP-TO-DATE   AVAILABLE
cache-db   1/1     1            1          ✅ now running!
```

---

### Step 7: Verify resource settings

```bash
kubectl describe pod -n ironclad | grep -A6 "Limits"
```

Expected:
```
Limits:
  memory:  30Mi
Requests:
  memory:  15Mi
```

✅ Memory request set to 15Mi
✅ Memory limit set to 30Mi (half of 60Mi max)
✅ Pods now running successfully

---

### LimitRange explained:

| Field | Meaning |
|---|---|
| `max` | No container can exceed this |
| `min` | No container can go below this |
| `defaultRequest` | Used if container doesn't specify request |
| `default` | Used if container doesn't specify limit |

> In exam — **always check `kubectl describe ns`** first to find the namespace limits before calculating! 💪

</details>

---

# ↩️ Restore Cluster State

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `reset_q13_baseline.sh` | Moving to next problem? Run this to remove all Q13 changes and restore clean cluster state |

---

### 🧹 Script : reset_q13_baseline.sh

**Done with this problem? Moving to the next one?**
Run this to remove all Q13 changes and restore a clean cluster state.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q13: Fix LimitRange Memory Violation
# reset_q13_baseline.sh
# ============================================================

set -euo pipefail

NAMESPACE="ironclad"
MANIFEST_DIR="$HOME/ckad/ironclad-ops"

echo ""
echo "==========================================="
echo " CKAD Q13 — Restoring cluster to baseline..."
echo "==========================================="
echo ""

echo "[1/2] Deleting namespace '$NAMESPACE' (Deployment + LimitRange)..."
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