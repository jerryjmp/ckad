## 🧩 Problem Statement

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task.

**Task:**

A web application is running in the namespace `external`. Deploy an nginx-based application and expose it via a Service `nginx-service` on port `8080`.

Create an Ingress resource named `external-ingress` to expose the application externally using the URL `external.sterling-web.local`.

All requests to `/web-portal` must be **rewritten to `/`** before forwarding to the backend.

Finally test access using:
```bash
curl -L http://external.sterling-web.local/web-portal
```

</details>

---

## 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

**Step 1: Install Traefik Ingress controller**

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
echo "$NODE_IP external.sterling-web.local" | sudo tee -a /etc/hosts
```

**Step 2: Create Deployment and Service**
```
k create ns external
```

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-app
  namespace: external
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-app
  template:
    metadata:
      labels:
        app: nginx-app
    spec:
      containers:
      - name: nginx-app
        image: devopstechtales/ckad-exam-questions:ingress-web-server
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: external
spec:
  selector:
    app: nginx-app
  ports:
  - protocol: TCP
    port: 8080
    targetPort: 80
EOF
```

**Step 2: Verify**

```bash
kubectl get all -n external
```

Scenario is ready — no Ingress or Middleware exists yet. ✅

</details>

---

## ✅ Solution

<details>
<summary>Click to expand the solution</summary>

---

### Step 1: Create Traefik Middleware for path rewrite

```bash
cat <<EOF | kubectl apply -f -
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: strip-prefix
  namespace: external
spec:
  stripPrefix:
    prefixes:
      - /web-portal
EOF
```

**Verify middleware created:**
```bash
kubectl get middleware -n external
```

---

### Step 2: Create Ingress with middleware annotation

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: external-ingress
  namespace: external
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: external-strip-prefix@kubernetescrd
spec:
  ingressClassName: traefik
  rules:
  - host: external.sterling-web.local
    http:
      paths:
      - path: /web-portal
        pathType: Prefix
        backend:
          service:
            name: nginx-service
            port:
              number: 8080
EOF
```

---

### Step 3: Verify Ingress

```bash
kubectl get ingress -n external
kubectl describe ingress nginx-ingress -n external
```

---

### Step 4: Test curl

```bash
curl -L http://external.sterling-web.local/web-portal
```

### Solution using Nginx Ingress Controller(Optional)

**No Middleware needed — just one annotation does the rewrite:**

**Step 1: Create Ingress**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: external-ingress
  namespace: external
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: external.sterling-web.local
    http:
      paths:
      - path: /web-portal
        pathType: Prefix
        backend:
          service:
            name: nginx-service
            port:
              number: 8080
EOF
```
</details>

---