# 🧩 Problem Statement (Debug Service & Ingress Misconfiguration)

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task; failure to do so may result in a score of **0**.

**Task:**

In the namespace `app-routing`, the Deployment `web-server` is exposed via the Ingress `web-ingress`. The manifest files for the Deployment, Service, and Ingress can be found in the directory `/ckad/app-routing/`.

The Deployment should be accessible, but it currently **returns an error**.

Identify and fix the issue by updating the relevant resources so the Deployment can be accessed as intended.

> **Note:** The Deployment is correct — **do NOT modify it**. Assume the Deployment is functional.

Finally, test access using:
```bash
curl -L http://web-app.local
```

</details>

---

# 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `setup_q05_problem_scenario.sh` | Installs Traefik (if needed), deploys web-server Deployment + buggy Service/Ingress — run before practice (re-run anytime to practice again) |

---

### 📥 Script : setup_q05_problem_scenario.sh

Run this **before you start practicing** this problem.
Re-run anytime you want to practice again after fixing.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q05: Debug Service & Ingress Misconfiguration
# setup_q05_problem_scenario.sh
# Deploys web-server + broken Service/Ingress (selector/port/name bugs)
# Run on: controlplane node
# ============================================================

set -euo pipefail

NAMESPACE="app-routing"
MANIFEST_DIR="$HOME/ckad/app-routing"
HOSTNAME_ENTRY="web-app.local"

echo ""
echo "==========================================="
echo " CKAD Q05 — Setting up Service/Ingress debug scenario..."
echo "==========================================="
echo ""

# ── Step 0: Revert solution-specific changes (fast) ────────────
# Only undoes what THIS question's solution fixes: the Service
# and Ingress manifest files. Rewriting them back to the buggy
# versions and re-applying is enough — no need to touch Traefik
# or the Deployment, which the solution never modifies.
echo "[0/6] Reverting any previous solution changes..."
mkdir -p "$MANIFEST_DIR"

cat <<EOF > "$MANIFEST_DIR/service.yaml"
apiVersion: v1
kind: Service
metadata:
  name: web-server-svc
  namespace: $NAMESPACE
spec:
  selector:
    app: web-backend
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
EOF

cat <<EOF > "$MANIFEST_DIR/ingress.yaml"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  namespace: $NAMESPACE
spec:
  ingressClassName: traefik
  rules:
  - host: $HOSTNAME_ENTRY
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-backend-svc
            port:
              number: 80
EOF

if kubectl get namespace "$NAMESPACE" &>/dev/null; then
  kubectl apply -f "$MANIFEST_DIR/service.yaml"
  kubectl apply -f "$MANIFEST_DIR/ingress.yaml"
fi
echo "  Reverted to buggy state."

# ── Step 1: Install helm (skip if already installed) ─────────
echo "[1/6] Checking/Installing helm..."
if ! command -v helm &>/dev/null; then
  curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
  chmod 700 /tmp/get_helm.sh
  /tmp/get_helm.sh
  echo "  helm installed."
else
  echo "  helm already installed, skipping."
fi

# ── Step 2: Install Traefik (skip if already installed) ───────
echo "[2/6] Checking/Installing Traefik..."
kubectl create namespace traefik --dry-run=client -o yaml | kubectl apply -f -

helm repo add traefik https://helm.traefik.io/traefik --force-update
helm repo update

cat <<EOF > /tmp/traefik-values.yaml
ports:
  web:
    port: 8000
    hostPort: 80
    containerPort: 8000
    expose:
      default: true

deployment:
  kind: DaemonSet

tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"

affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
EOF

if helm status traefik -n traefik &>/dev/null; then
  echo "  Traefik already installed, skipping helm install."
else
  helm install traefik traefik/traefik \
    --namespace traefik \
    --values /tmp/traefik-values.yaml
fi

echo "  Waiting for Traefik pod to be Ready..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=traefik -n traefik --timeout=120s || true
echo "  Traefik should be up."

# ── Step 3: Add hosts entry ────────────────────────────────────
echo "[3/6] Adding $HOSTNAME_ENTRY to /etc/hosts..."
NODE_IP=$(kubectl get nodes -o wide | grep control-plane | awk '{print $6}')
sudo sed -i "/${HOSTNAME_ENTRY}/d" /etc/hosts
echo "$NODE_IP $HOSTNAME_ENTRY" | sudo tee -a /etc/hosts >/dev/null
echo "  Hosts entry added: $NODE_IP $HOSTNAME_ENTRY"

# ── Step 4: Create namespace + Deployment (correct, do not touch) ──
echo "[4/6] Ensuring namespace and web-server Deployment..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF > "$MANIFEST_DIR/deployment.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-server
  namespace: $NAMESPACE
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-server
  template:
    metadata:
      labels:
        app: web-server
    spec:
      containers:
      - name: web-server
        image: devopstechtales/ckad-exam-questions:ingress-web-server
        ports:
        - containerPort: 80
EOF

kubectl apply -f "$MANIFEST_DIR/deployment.yaml"

echo "  Waiting for pods to be Ready..."
kubectl wait --for=condition=ready pod -l app=web-server -n "$NAMESPACE" --timeout=120s
echo "  Pods Ready."

# ── Step 5: Re-apply broken Service + Ingress ──────────────────
echo "[5/6] Applying broken Service and Ingress..."
kubectl apply -f "$MANIFEST_DIR/service.yaml"
kubectl apply -f "$MANIFEST_DIR/ingress.yaml"
echo "  Applied (intentionally broken)."

# ── Step 6: Verify scenario is broken ──────────────────────────
echo "[6/6] Verifying scenario is broken..."
kubectl get deployment,svc,ingress -n "$NAMESPACE"
echo "  Testing curl (expected to fail/error):"
curl -sL -m 5 "http://${HOSTNAME_ENTRY}" || echo "  (as expected — request failed)"

echo ""
echo "✅ Q05 scenario is ready!"
echo ""
echo "   web-server Deployment is healthy (do not modify it)."
echo "   Service and Ingress have intentional bugs."
echo "   Manifests at: $MANIFEST_DIR/"
echo "   Now go fix it! 💪"
echo ""
```

</details>

---

# ✅ Solution

<details>
<summary>Click to expand the solution</summary>

---

### Step 1: Check all manifest files

```bash
cat ~/ckad/app-routing/deployment.yaml
cat ~/ckad/app-routing/service.yaml
cat ~/ckad/app-routing/ingress.yaml
```

---

### Step 2: Cross-check the files

**Deployment labels:**
```yaml
selector:
  matchLabels:
    app: web-server       # ✅ deployment uses this label
template:
  labels:
    app: web-server       # ✅ pods have this label
containerPort: 80         # ✅ container listens on 80
```

**Service — spot the bugs:**
```yaml
selector:
  app: web-backend        # ❌ should be web-server
targetPort: 8080          # ❌ should be 80
```

**Ingress — spot the bug:**
```yaml
service:
  name: web-backend-svc   # ❌ should be web-server-svc
```

---

### Step 3: Fix the Service file

```bash
vim ~/ckad/app-routing/service.yaml
```

Corrected file:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-server-svc
  namespace: app-routing
spec:
  selector:
    app: web-server         # ✅ fixed label
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80          # ✅ fixed targetPort
```

---

### Step 4: Fix the Ingress file

```bash
vim ~/ckad/app-routing/ingress.yaml
```

Corrected file:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  namespace: app-routing
spec:
  ingressClassName: traefik
  rules:
  - host: web-app.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-server-svc    # ✅ fixed service name
            port:
              number: 80
```

---

### Step 5: Apply the fixes

```bash
kubectl apply -f ~/ckad/app-routing/service.yaml
kubectl apply -f ~/ckad/app-routing/ingress.yaml
```

---

### Step 6: Verify endpoints are now populated

```bash
kubectl get endpoints web-server-svc -n app-routing
```

You should now see pod IPs listed — if endpoints were empty before, they are now populated. ✅

---

### Step 7: Test curl

```bash
curl -L http://web-app.local
```

Expected output:
```
Hello from web-server!
```

✅ Deployment is accessible
✅ Service selector matches pod labels
✅ Service targetPort matches container port
✅ Ingress points to correct service name

</details>

---

# ↩️ Restore Cluster State

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `reset_q05_baseline.sh` | Moving to next problem? Run this to remove all Q05 changes and restore clean cluster state |

---

### 🧹 Script : reset_q05_baseline.sh

**Done with this problem? Moving to the next one?**
Run this to remove all Q05 changes and restore a clean cluster state.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q05: Debug Service & Ingress Misconfiguration
# reset_q05_baseline.sh
# ============================================================

set -euo pipefail

NAMESPACE="app-routing"
MANIFEST_DIR="$HOME/ckad/app-routing"
HOSTNAME_ENTRY="web-app.local"

echo ""
echo "==========================================="
echo " CKAD Q05 — Restoring cluster to baseline..."
echo "==========================================="
echo ""

# ── Step 1: Remove app-routing namespace ───────────────────────
echo "[1/4] Deleting namespace '$NAMESPACE' (Deployment, Service, Ingress)..."
kubectl delete namespace "$NAMESPACE" --ignore-not-found
echo "  Waiting for namespace deletion to complete..."
while kubectl get namespace "$NAMESPACE" &>/dev/null; do
  sleep 2
done
echo "  Namespace removed."

# ── Step 2: Uninstall Traefik ──────────────────────────────────
echo "[2/4] Uninstalling Traefik..."
if helm status traefik -n traefik &>/dev/null; then
  helm uninstall traefik -n traefik
fi
kubectl delete namespace traefik --ignore-not-found
echo "  Traefik removed."

# ── Step 3: Remove hosts entry ─────────────────────────────────
echo "[3/4] Removing $HOSTNAME_ENTRY from /etc/hosts..."
sudo sed -i "/${HOSTNAME_ENTRY}/d" /etc/hosts
echo "  Hosts entry removed."

# ── Step 4: Clean up manifest directory ─────────────────────────
echo "[4/4] Removing manifest directory..."
rm -rf "$MANIFEST_DIR"
rm -f /tmp/traefik-values.yaml
echo "  Manifest directory removed."

echo ""
echo "✅ Cluster is back to baseline!"
echo ""
echo "   Safe to move to next problem. 🚀"
echo ""
```

</details>

---