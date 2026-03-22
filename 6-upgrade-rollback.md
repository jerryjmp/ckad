## 📄 CKAD Question 1 — Upgrade and Rollback


### 🧩 Problem Statement

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task.

**Task:**

1. Update the **rolling update strategy** of the Deployment `nginx-frontend` in the namespace `webteam` — set `maxSurge` to `5%` and `maxUnavailable` to `5%`.

2. Update the Deployment `nginx-frontend` to use the container image `devopstechtales/ckad-exam-questions:1.15.7`.

3. **Roll back** the Deployment `nginx-frontend` to its **previous version**.

</details>

---

### 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

Run the following commands to create the scenario exactly as it would appear in the exam.

**Step 1: Create the namespace**

```bash
kubectl create namespace webteam
```

**Step 2: Create the Deployment running the old image version**

```bash
kubectl create deployment nginx-frontend \
  --image=devopstechtales/ckad-exam-questions:1.14.7 \
  --namespace=webteam \
  --replicas=1
```

**Step 3: Verify**

```bash
kubectl get deployment nginx-frontend -n webteam
kubectl describe deployment nginx-frontend -n webteam
```

You should see:
- Image: `devopstechtales/ckad-exam-questions:1.14.7`
- No rolling update strategy configured yet (defaults will be in place)

Scenario is ready. ✅

</details>

---

### ✅ Solution

<details>
<summary>Click to expand the solution</summary>

---

### Task 1: Update the Rolling Update Strategy

Edit the deployment:

```bash
kubectl edit deployment nginx-frontend -n webteam
```

Under `spec.strategy`, update or add the following:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 5%
    maxUnavailable: 5%
```

Save and exit.

Or use patch command directly:

```bash
kubectl patch deployment nginx-frontend -n webteam \
  -p '{"spec":{"strategy":{"type":"RollingUpdate","rollingUpdate":{"maxSurge":"5%","maxUnavailable":"5%"}}}}'
```

**Verify:**

```bash
kubectl describe deployment nginx-frontend -n webteam | grep -A3 "RollingUpdateStrategy"
```

---

### Task 2: Update the Image Version

```bash
kubectl set image deployment/nginx-frontend \
  ckad-exam-questions=devopstechtales/ckad-exam-questions:1.15.7 \
  -n webteam \
  --record
```

> ⚠️ `--record` saves this command in the rollout history, which is needed for Task 3.

**Verify the rollout:**

```bash
kubectl rollout status deployment/nginx-frontend -n webteam
```

**Check rollout history:**

```bash
kubectl rollout history deployment/nginx-frontend -n webteam
```

You should see **2 revisions** — revision 1 (old image) and revision 2 (new image).

---

### Task 3: Roll Back to Previous Version

```bash
kubectl rollout undo deployment/nginx-frontend -n webteam
```

**Verify the rollback:**

```bash
kubectl rollout status deployment/nginx-frontend -n webteam
kubectl describe deployment nginx-frontend -n webteam | grep Image
```

Image should now show `devopstechtales/ckad-exam-questions:1.14.7` again. ✅

</details>

---