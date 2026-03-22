## 🧩 Problem Statement

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task; failure to do so may result in a score of **0**.

**Context:**
You need to move hardcoded secrets in a Pod's environment variables to a Kubernetes Secret and use the Secret in the Pod.

**Task:**

1. Create a new Secret named `postgres-creds` in the namespace `data-layer`. It must contain the **three secret values** currently hardcoded in the environment variables of the Pods from the Deployment `postgres-db` running in the namespace `data-layer`. Use the following keys:
   - `username`
   - `database`
   - `password`

2. Modify the Deployment `postgres-db` to use the new Secret. Set the environment variables so their values are taken from the `username`, `database`, and `password` keys of the new Secret.

   > **Do NOT delete the existing Deployment**, as this will result in a lower score.

</details>

---

## 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

**Step 1: Create namespace**

```bash
kubectl create namespace data-layer
```

**Step 2: Create Deployment with real postgres and hardcoded env vars**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-db
  namespace: data-layer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres-db
  template:
    metadata:
      labels:
        app: postgres-db
    spec:
      containers:
      - name: postgres-db
        image: postgres:15
        env:
        - name: POSTGRES_USER
          value: "admin"            # ❌ hardcoded
        - name: POSTGRES_DB
          value: "myappdb"          # ❌ hardcoded
        - name: POSTGRES_PASSWORD
          value: "S3cur3P@ss!"      # ❌ hardcoded
EOF
```

**Step 3: Verify postgres is running**

```bash
kubectl get pods -n data-layer
kubectl logs -n data-layer deploy/postgres-db | tail -5
```

Expected log output:
```
PostgreSQL init process complete; ready for start up.
LOG: database system is ready to accept connections
```

**Step 4: Verify hardcoded values visible in deployment**

```bash
kubectl describe deployment postgres-db -n data-layer | grep -A6 "Environment"
```

Expected output:
```
Environment:
  POSTGRES_USER:      admin
  POSTGRES_DB:        myappdb
  POSTGRES_PASSWORD:  S3cur3P@ss!
```

Scenario is ready — hardcoded secrets are visible! ✅

</details>

---

## ✅ Solution

<details>
<summary>Click to expand the solution</summary>

---

### Step 1: Check the Deployment to find hardcoded values

```bash
kubectl describe deployment postgres-db -n data-layer | grep -A6 "Environment"
```

Output:
```
Environment:
  POSTGRES_USER:      admin
  POSTGRES_DB:        myappdb
  POSTGRES_PASSWORD:  S3cur3P@ss!
```

Note down all three values — these go into the Secret.

---

### Step 2: Create the Secret with those values

```bash
kubectl create secret generic postgres-creds \
  --from-literal=username=admin \
  --from-literal=database=myappdb \
  --from-literal=password=S3cur3P@ss! \
  --namespace=data-layer
```

**Verify Secret created:**

```bash
kubectl get secret postgres-creds -n data-layer
kubectl describe secret postgres-creds -n data-layer
```

Output:
```
Name:         postgres-creds
Namespace:    data-layer
Type:         Opaque

Data
====
database:  7 bytes
password:  11 bytes
username:  5 bytes
```

> Values are stored base64 encoded — never shown in plain text ✅

---

### Step 3: Update Deployment to use Secret

```bash
kubectl edit deployment postgres-db -n data-layer
```

**Before (hardcoded):**
```yaml
env:
- name: POSTGRES_USER
  value: "admin"
- name: POSTGRES_DB
  value: "myappdb"
- name: POSTGRES_PASSWORD
  value: "S3cur3P@ss!"
```

**After (from Secret):**
```yaml
env:
- name: POSTGRES_USER
  valueFrom:
    secretKeyRef:
      name: postgres-creds
      key: username
- name: POSTGRES_DB
  valueFrom:
    secretKeyRef:
      name: postgres-creds
      key: database
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: postgres-creds
      key: password
```

Save and exit.

---

### Step 4: Verify rollout completed

```bash
kubectl rollout status deployment/postgres-db -n data-layer
```

---

### Step 5: Verify env vars now coming from Secret

```bash
kubectl describe deployment postgres-db -n data-layer | grep -A15 "Environment"
```

Expected output:
```
Environment:
  POSTGRES_USER:      <set to the key 'username' in secret 'postgres-creds'>
  POSTGRES_DB:        <set to the key 'database' in secret 'postgres-creds'>
  POSTGRES_PASSWORD:  <set to the key 'password' in secret 'postgres-creds'>
```

---

### Step 6: Verify postgres is still working with Secret values

```bash
# exec into pod
kubectl exec -it -n data-layer deploy/postgres-db -- \
  psql -U admin -d myappdb -c "\conninfo"
```

Expected output:
```
You are connected to database "myappdb" as user "admin" 
via socket in "/var/run/postgresql" at port "5432".
```

✅ Postgres still running correctly
✅ Values now coming from Secret not hardcoded
✅ Connection works with Secret-based credentials


</details>

---