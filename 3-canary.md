## 📄 CKAD Question 3 — Canary Deployment

### 🧩 Problem Statement

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

### 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

**Step 1: Create the namespace**

```bash
kubectl create namespace swift-birds
```

**Step 2: Create the manifest directory**

```bash
mkdir -p ~/ckad/swift-birds
```

**Step 3: Create the stable deployment manifest**

```bash
cat <<EOF > ~/ckad/swift-birds/stable-falcon-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stable-falcon-deployment
  namespace: swift-birds
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
```

**Step 4: Apply the deployment**

```bash
kubectl apply -f /ckad/swift-birds/stable-falcon-deployment.yaml
```

**Step 5: Create the Service**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: falcon-service
  namespace: swift-birds
spec:
  selector:
    app: falcon
  ports:
  - port: 80
    targetPort: 80
EOF
```

**Step 6: Verify**

```bash
kubectl get deployment -n swift-birds
kubectl get svc -n swift-birds
kubectl get pods -n swift-birds
```

You should see:
- 5 pods running from `stable-falcon-deployment`
- `falcon-service` pointing to all 5 pods via label `app: falcon` ✅

Scenario is ready. ✅

</details>

---

### ✅ Solution

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
vim /ckad/swift-birds/canary-falcon-deployment.yaml
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
kubectl apply -f /ckad/swift-birds/canary-falcon-deployment.yaml
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