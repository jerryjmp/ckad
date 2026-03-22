## 🧩 Problem Statement

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task; failure to do so may result in a score of **0**.

**Context:**
You need to deploy an application developed for an older version of Kubernetes on a cluster running the latest Kubernetes version.

**Task:**

1. Fix any **API deprecation issues** in the manifest file `/ckad/legacy-app/app.yaml` so the application can be deployed on the Kubernetes cluster.
   > Note: The application was developed for **Kubernetes v1.15**, while the cluster runs **Kubernetes v1.35**.

2. Deploy the application specified in the updated manifest file `/ckad/legacy-app/app.yaml` in the namespace `sandstone`.

</details>

---

## 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

**Step 1: Create namespace and directory**

```bash
kubectl create namespace sandstone
mkdir -p ~/ckad/legacy-app
```

**Step 2: Create the manifest with deprecated APIs**

```bash
cat <<EOF > ~/ckad/legacy-app/app.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: legacy-web
  namespace: sandstone
spec:
  replicas: 2
  template:
    metadata:
      labels:
        app: legacy-web
    spec:
      containers:
      - name: legacy-web
        image: devopstechtales/ckad-exam-questions:1.15.7
        command:
        - sh
        - -c
        - while true; do echo 'Legacy App Running'; sleep 10; done
        ports:
        - containerPort: 80
EOF
```

**Step 3: Try to apply — it should fail**

```bash
kubectl apply -f /ckad/legacy-app/app.yaml
```

Expected error:
```
error: resource mapping not found for name: "legacy-web" 
namespace: "sandstone" from "/ckad/legacy-app/app.yaml": 
no matches for kind "Deployment" in version "extensions/v1beta1"
ensure CRDs are installed first
```

Scenario is ready. ✅

</details>

---

## ✅ Solution

<details>
<summary>Click to expand the solution</summary>


### Step 1: Check the manifest file

```bash
cat /ckad/legacy-app/app.yaml
```

Identify the deprecated API:
```yaml
apiVersion: extensions/v1beta1    # ❌ this is the problem
kind: Deployment
```


### Step 2: Understand API deprecation history

| Resource | Old API (deprecated) | New API (current) |
|---|---|---|
| Deployment | `extensions/v1beta1` | `apps/v1` |
| DaemonSet | `extensions/v1beta1` | `apps/v1` |
| ReplicaSet | `extensions/v1beta1` | `apps/v1` |
| Ingress | `extensions/v1beta1` | `networking.k8s.io/v1` |
| NetworkPolicy | `extensions/v1beta1` | `networking.k8s.io/v1` |
| PodSecurityPolicy | `extensions/v1beta1` | **Removed** in v1.25 |

> In exam always check `apiVersion` first when you see a legacy manifest!


### Step 3: Fix the manifest

#### Fix 1: Update apiVersion:

```bash
vim /ckad/legacy-app/app.yaml
```

Change:
```yaml
apiVersion: extensions/v1beta1    # ❌ old
```

To:
```yaml
apiVersion: apps/v1               # ✅ current
```

#### Fix 2: Add selector field (mandatory in apps/v1)

```
spec:
  replicas: 2
  selector:               # ✅ must add this — required in apps/v1
    matchLabels:
      app: legacy-web     # must match template.metadata.labels exactly
  template:
    metadata:
      labels:
        app: legacy-web
```

Full corrected file:

```yaml
apiVersion: apps/v1               # ✅ Fix 1: updated apiVersion
kind: Deployment
metadata:
  name: legacy-web
  namespace: sandstone
spec:
  replicas: 2
  selector:                       # ✅ Fix 2: added mandatory selector
    matchLabels:
      app: legacy-web
  template:
    metadata:
      labels:
        app: legacy-web
    spec:
      containers:
      - name: legacy-web
        image: devopstechtales/ckad-exam-questions:1.15.7
        command:
        - sh
        - -c
        - while true; do echo 'Legacy App Running'; sleep 10; done
        ports:
        - containerPort: 80
```


### Step 4: Deploy the application

```bash
kubectl apply -f /ckad/legacy-app/app.yaml
```

Expected output:
```
deployment.apps/legacy-web created
```


### Step 5: Verify deployment

```bash
kubectl get deployment legacy-web -n sandstone
kubectl get pods -n sandstone
```

Expected:
```
NAME         READY   UP-TO-DATE   AVAILABLE
legacy-web   2/2     2            2
```

✅ API deprecation fixed
✅ selector → add matchLabels matching pod template labels
✅ Application deployed successfully in `sandstone` namespace


### How to quickly find deprecated APIs in exam:

```bash
# check what apiVersion is valid for a resource
kubectl explain deployment | head -5

# output shows:
# VERSION: apps/v1   ← this is the correct current apiVersion

```

> `kubectl explain` is your best friend for API version checks in exam! ✅

</details>

---