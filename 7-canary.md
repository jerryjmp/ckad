# 🧩 Problem Statement (Canary Deployment)

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task; failure to do so may result in a score of **0**.

**Context:**
To test a new application release, you need to prepare a **canary deployment** strategy.

**Task:**

The Service `falcon-service` in the namespace `swift-birds` points to **5 Pods** created by the Deployment `stable-falcon-deployment`. The manifest file for `stable-falcon-deployment` can be found at `/ckad/swift-birds/`.

1. Create an **identical Deployment** in the same namespace, named `canary-falcon-deployment`.
2. Modify **both Deployments** so that:
   - The **maximum total number of Pods** running in the namespace `swift-birds` is **10**
   - **40% of traffic** to `falcon-service` is routed to the Pods of `canary-falcon-deployment`

</details>

---

# 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `setup_q03_problem_scenario.sh` | Deploys namespace, stable Deployment, Service, and manifest file — run before practice (re-run anytime to practice again) |

---

### 📥 Script : setup_q03_problem_scenario.sh

Run this **before you start practicing** this problem.
Re-run anytime you want to practice again after fixing.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q03: Canary Deployment
# setup_q03_problem_scenario.sh
# Deploys stable-falcon-deployment (5 replicas) + Service
# Run on: controlplane node
# ============================================================

set -euo pipefail

NAMESPACE="swift-birds"
MANIFEST_DIR="$HOME/ckad/swift-birds"

echo ""
echo "==========================================="
echo " CKAD Q03 — Setting up Canary Deployment scenario..."
echo "==========================================="
echo ""

# ── Step 0: Revert solution-specific changes (fast) ────────────
# Only undoes what THIS question's solution changes:
# - canary-falcon-deployment (created by solution)
# - stable-falcon-deployment replica count (scaled by solution)
# - canary manifest file (created by solution)
# Everything else below is applied idempotently.
echo "[0/5] Reverting any previous solution changes..."
kubectl delete deployment canary-falcon-deployment -n "$NAMESPACE" --ignore-not-found
rm -f "$MANIFEST_DIR/canary-falcon-deployment.yaml"
if kubectl get deployment stable-falcon-deployment -n "$NAMESPACE" &>/dev/null; then
  kubectl scale deployment stable-falcon-deployment -n "$NAMESPACE" --replicas=5
fi
echo "  Reverted."

# ── Step 1: Create the namespace ───────────────────────────────
echo "[1/5] Ensuring namespace '$NAMESPACE' exists..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo "  Namespace ready."

# ── Step 2: Create the manifest directory + stable deployment file ──
echo "[2/5] Writing manifest file to $MANIFEST_DIR..."
mkdir -p "$MANIFEST_DIR"

cat <<EOF > "$MANIFEST_DIR/stable-falcon-deployment.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stable-falcon-deployment
  namespace: $NAMESPACE
spec:
  replicas: 5
  selector:
    matchLabels:
      app: falcon
  template:
    metadata:
      labels:
        app: falcon
    spec:
      containers:
      - name: falcon
        image: devopstechtales/ckad-exam-questions:canary
        command:
        - sh
        - -c
        - while true; do echo 'Falcon App Running'; sleep 30; done
        imagePullPolicy: IfNotPresent
EOF
echo "  Manifest written."

# ── Step 3: Apply the stable deployment ─────────────────────────
echo "[3/5] Applying stable-falcon-deployment..."
kubectl apply -f "$MANIFEST_DIR/stable-falcon-deployment.yaml"

echo "  Waiting for pods to be Ready..."
kubectl wait --for=condition=ready pod -l app=falcon -n "$NAMESPACE" --timeout=120s
echo "  Pods Ready."

# ── Step 4: Create the Service ──────────────────────────────────
echo "[4/5] Applying falcon-service..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: falcon-service
  namespace: $NAMESPACE
spec:
  selector:
    app: falcon
  ports:
  - port: 80
    targetPort: 80
EOF
echo "  Service ready."

# ── Step 5: Verify ────────────────────────────────────────────────
echo "[5/5] Verifying resources..."
kubectl get deployment -n "$NAMESPACE"
kubectl get svc -n "$NAMESPACE"
kubectl get pods -n "$NAMESPACE"

echo ""
echo "✅ Q03 scenario is ready!"
echo ""
echo "   5 pods running from stable-falcon-deployment."
echo "   No canary-falcon-deployment exists yet."
echo "   Manifest available at: $MANIFEST_DIR/stable-falcon-deployment.yaml"
echo "   Now go fix it! 💪"
echo ""
```

</details>

---

# ✅ Solution

<details>
<summary>Click to expand the solution</summary>

---

### Step 1: Check the existing deployment manifest

```bash
cat ~/ckad/swift-birds/stable-falcon-deployment.yaml
```

---

### Step 2: Understand the traffic split logic

The service `falcon-service` uses label `app: falcon` to route traffic.
Traffic is distributed **proportionally based on number of pods**.

We need:
- Total pods = **10**
- 40% to canary = **4 pods**
- 60% to stable = **6 pods**

```
canary pods = 10 × 40% = 4
stable pods = 10 - 4    = 6
```

---

### Step 3: Create canary deployment from the manifest

```bash
cp ~/ckad/swift-birds/stable-falcon-deployment.yaml \
   ~/ckad/swift-birds/canary-falcon-deployment.yaml
```

Edit the canary file:

```bash
vim ~/ckad/swift-birds/canary-falcon-deployment.yaml
```

Change the following:

```yaml
metadata:
  name: canary-falcon-deployment    # ✅ changed name
  namespace: swift-birds
spec:
  replicas: 4                       # ✅ 40% of 10
  selector:
    matchLabels:
      app: falcon                   # ✅ keep same label so service routes traffic
  template:
    metadata:
      labels:
        app: falcon                 # ✅ keep same label
    spec:
      containers:
      - name: falcon
        image: devopstechtales/ckad-exam-questions:canary
```

Apply it:

```bash
kubectl apply -f ~/ckad/swift-birds/canary-falcon-deployment.yaml
```

---

### Step 4: Update stable deployment replicas to 6

```bash
kubectl scale deployment stable-falcon-deployment \
  -n swift-birds --replicas=6
```

---

### Step 5: Verify total pods and traffic split

```bash
kubectl get pods -n swift-birds --show-labels
```

```bash
kubectl get deployment -n swift-birds
```

Expected output:

```
NAME                         READY   UP-TO-DATE   AVAILABLE
stable-falcon-deployment     6/6     6            6
canary-falcon-deployment     4/4     4            4
```

Total pods = **10** ✅
Canary traffic = 4/10 = **40%** ✅
Stable traffic = 6/10 = **60%** ✅

---

### Step 6: Verify service endpoints

```bash
kubectl get endpoints falcon-service -n swift-birds
```

You should see **10 endpoint IPs** — all 10 pods are receiving traffic through the same service. ✅

</details>

---

# ↩️ Restore Cluster State

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `reset_q03_baseline.sh` | Moving to next problem? Run this to remove all Q03 changes and restore clean cluster state |

---

### 🧹 Script : reset_q03_baseline.sh

**Done with this problem? Moving to the next one?**
Run this to remove all Q03 changes and restore a clean cluster state.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q03: Canary Deployment
# reset_q03_baseline.sh
# ============================================================

set -euo pipefail

NAMESPACE="swift-birds"
MANIFEST_DIR="$HOME/ckad/swift-birds"

echo ""
echo "==========================================="
echo " CKAD Q03 — Restoring cluster to baseline..."
echo "==========================================="
echo ""

echo "[1/2] Deleting namespace '$NAMESPACE' (Deployments + Service)..."
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