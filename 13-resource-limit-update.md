## 🧩 Problem Statement

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

## 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

**Step 1: Create namespace with LimitRange**

```bash
kubectl create namespace ironclad
```

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: ironclad-limits
  namespace: ironclad
spec:
  limits:
  - type: Container
    max:
      memory: "60Mi"        # maximum memory allowed per container
    defaultRequest:
      memory: "8Mi"         # default request if not specified
    default:
      memory: "16Mi"        # default limit if not specified
EOF
```

**Verify LimitRange:**

```bash
kubectl describe ns ironclad
```

Expected output:
```
Resource Limits
Type       Resource  Min  Max   Default Request  Default Limit
----       --------  ---  ---   ---------------  -------------
Container  memory    -    40Mi  8Mi              16Mi
```

---

**Step 2: Create manifest directory**

```bash
mkdir -p ~/ckad/ironclad-ops
```

**Step 3: Create the Deployment manifest with excessive memory**

```bash
cat <<EOF > ~/ckad/ironclad-ops/cache-db.yaml
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
            memory: "50Mi"    # ❌ exceeds max of 40Mi
          limits:
            memory: "80Mi"    # ❌ exceeds max of 40Mi
EOF
```

**Step 4: Apply the manifest — pods will fail**

```bash
kubectl apply -f /ckad/ironclad-ops/cache-db.yaml
```

**Step 5: Verify pods are failing**

```bash
kubectl get deployment cache-db -n ironclad
kubectl get pods -n ironclad
kubectl describe pod -n ironclad | grep -A5 "Events"
```

Expected:
```
NAME       READY   UP-TO-DATE   AVAILABLE
cache-db   0/1     0            0
```

Events will show:
```
Error: maximum memory usage per Container is 40Mi, 
but limit is 80Mi
```

Scenario is ready — pods failing due to exceeded memory! ✅

</details>

---

## ✅ Solution

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

```bash
kubectl describe pod -n ironclad | grep -A5 "Events"
```

Output:
```
Error: maximum memory usage per Container is 40Mi
but limit is 80Mi
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
- Memory limit for pod = **half of max** = `40Mi / 2` = `20Mi`
- Memory request = `15Mi` (given in task)

---

### Step 3: Check the manifest file

```bash
cat /ckad/ironclad-ops/cache-db.yaml
```

Identify the problem:
```yaml
resources:
  requests:
    memory: "50Mi"    # ❌ exceeds namespace max of 40Mi
  limits:
    memory: "80Mi"    # ❌ exceeds namespace max of 40Mi
```

---

### Step 4: Fix the manifest

```bash
vim /ckad/ironclad-ops/cache-db.yaml
```

Update the resources section:

```yaml
resources:
  requests:
    memory: "15Mi"    # ✅ as specified in task
  limits:
    memory: "20Mi"    # ✅ half of 40Mi max = 20Mi
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
        image: devopstechtales/ckad-exam-questions:1.12.7
        command:
        - sh
        - -c
        - while true; do echo 'Cache Running'; sleep 10; done
        resources:
          requests:
            memory: "15Mi"    # ✅ fixed
          limits:
            memory: "30Mi"    # ✅ fixed - half of 40Mi
```

---

### Step 5: Apply the fixed manifest

```bash
kubectl apply -f /ckad/ironclad-ops/cache-db.yaml
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
  memory:  20Mi
Requests:
  memory:  15Mi
```

✅ Memory request set to 15Mi
✅ Memory limit set to 20Mi (half of 40Mi max)
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