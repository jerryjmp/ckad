## 🧩 Problem Statement

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

## 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

**Step 1: Install Traefik Ingress Controller**

**install helm**:

```
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh
./get_helm.sh
```

**create namespace**:

```
kubectl create namespace traefik
```

**install traefik using helm**:

```
helm repo add traefik https://helm.traefik.io/traefik
```
```
helm repo update
```
```
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
```
```
helm install traefik traefik/traefik \
  --namespace traefik \
  --values /tmp/traefik-values.yaml
```

**get controlplane node IP**:
```
NODE_IP=$(kubectl get nodes -o wide | grep control-plane | awk '{print $6}')
```
**add to /etc/hosts**:
```
echo "$NODE_IP web-app.local" | sudo tee -a /etc/hosts
```

---

**Step 2: Create namespace and directory**

```bash
kubectl create namespace app-routing
mkdir -p ~/ckad/app-routing
```

---

**Step 3: Create the Deployment manifest (correct — do not touch)**

```bash
cat <<EOF > ~/ckad/app-routing/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-server
  namespace: app-routing
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
```

---

**Step 4: Create the Service manifest — with intentional bugs**

```bash
cat <<EOF > ~/ckad/app-routing/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-server-svc
  namespace: app-routing
spec:
  selector:
    app: web-backend 
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
EOF
```

---

**Step 5: Create the Ingress manifest — with intentional bug**

```bash
cat <<EOF > ~/ckad/app-routing/ingress.yaml
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
            name: web-backend-svc
            port:
              number: 80
EOF
```

---

**Step 6: Apply all manifests**

```bash
kubectl apply -f /ckad/app-routing/deployment.yaml
kubectl apply -f /ckad/app-routing/service.yaml
kubectl apply -f /ckad/app-routing/ingress.yaml
```

---

**Step 8: Verify scenario is broken**


```bash
curl -L http://web-app.local
```

Scenario is ready. ✅

</details>

---

## ✅ Solution

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
vim /ckad/app-routing/service.yaml
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
vim /ckad/app-routing/ingress.yaml
```

Corrected file:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  namespace: app-routing
spec:
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