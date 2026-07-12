# 🧩 Problem Statement (CronJob - DNS Checker)

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task.

**Task:**

1. Create a CronJob named `dns-checker` that runs a Pod with a single container:
   - Container name: `dns-check`
   - Image: `busybox`
   - Command: `["sh", "-c", "grep -i nameserver /etc/resolv.conf"]`
   - Configure the CronJob with:
     - Run **every 30 minutes**
     - Retain **96 completed** Jobs
     - Retain **196 failed** Jobs
     - **Never restart** the Pod
     - Terminate the Pod after **8 seconds**

2. For testing purposes, **manually create and run a Job** named `dns-checker-test` from the CronJob `dns-checker`

</details>

---

# 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `setup_q04_problem_scenario.sh` | Creates the `cron-ops` namespace — run before practice (re-run anytime to practice again) |

---

### 📥 Script : setup_q04_problem_scenario.sh

Run this **before you start practicing** this problem.
Re-run anytime you want to practice again after fixing.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q04: CronJob - DNS Checker
# setup_q04_problem_scenario.sh
# Creates cron-ops namespace only — CronJob built from scratch
# Run on: controlplane node
# ============================================================

set -euo pipefail

NAMESPACE="cron-ops"

echo ""
echo "==========================================="
echo " CKAD Q04 — Setting up CronJob scenario..."
echo "==========================================="
echo ""

# ── Step 0: Revert solution-specific changes (fast) ────────────
# Only undoes what THIS question's solution creates:
# - CronJob dns-checker
# - Job dns-checker-test, plus any Jobs the CronJob's own
#   schedule may have spawned (this namespace only ever holds
#   CronJob-related jobs, so a full jobs wipe is safe here).
echo "[0/2] Reverting any previous solution changes..."
kubectl delete cronjob dns-checker -n "$NAMESPACE" --ignore-not-found
kubectl delete jobs --all -n "$NAMESPACE" --ignore-not-found
echo "  Reverted."

# ── Step 1: Create the namespace ───────────────────────────────
echo "[1/2] Ensuring namespace '$NAMESPACE' exists..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo "  Namespace ready."

# ── Step 2: Verify ────────────────────────────────────────────────
echo "[2/2] Verifying namespace..."
kubectl get namespace "$NAMESPACE"
kubectl get cronjob,job,pods -n "$NAMESPACE"

echo ""
echo "✅ Q04 scenario is ready!"
echo ""
echo "   No CronJob or Job exists yet."
echo "   Now go create dns-checker! 💪"
echo ""
```

</details>

---

# ✅ Solution

<details>
<summary>Click to expand the solution</summary>

---

### Step 1: Create the CronJob

```bash
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: dns-checker
  namespace: cron-ops
spec:
  schedule: "*/30 * * * *"           # ✅ every 30 minutes
  successfulJobsHistoryLimit: 96     # ✅ retain 96 completed jobs
  failedJobsHistoryLimit: 196        # ✅ retain 196 failed jobs
  jobTemplate:
    spec:
      activeDeadlineSeconds: 8       # ✅ terminate pod after 8 seconds
      template:
        spec:
          restartPolicy: Never       # ✅ never restart pod
          containers:
          - name: dns-check
            image: busybox
            command:
            - sh
            - -c
            - grep -i nameserver /etc/resolv.conf
EOF
```

---

### Step 2: Verify CronJob created

```bash
kubectl get cronjob dns-checker -n cron-ops
```

Expected output:
```
NAME          SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
dns-checker   */30 * * * *  False     0        <none>          5s
```

---

### Step 3: Describe CronJob to verify all settings

```bash
kubectl describe cronjob dns-checker -n cron-ops
```

Expected output:
```
Name:                          dns-checker
Namespace:                     cron-ops
Schedule:                      */30 * * * *
Suspend:                       False
Successful Job History Limit:  96
Failed Job History Limit:      196
Starting Deadline Seconds:     <unset>
Concurrency Policy:            Allow
```

---

### Step 4: Manually trigger a Job from CronJob for testing

```bash
kubectl create job dns-checker-test \
  --from=cronjob/dns-checker \
  --namespace=cron-ops
```

---

### Step 5: Verify Job created and running

```bash
kubectl get job dns-checker-test -n cron-ops
```

Expected output:
```
NAME               COMPLETIONS   DURATION   AGE
dns-checker-test   0/1           3s         3s
```

---

### Step 6: Check Job pod logs

```bash
# get pod name
kubectl get pods -n cron-ops

# check logs
kubectl logs -n cron-ops -l job-name=dns-checker-test
```

Expected output:
```
nameserver 10.96.0.10
nameserver 8.8.8.8
```

✅ CronJob created with correct schedule
✅ History limits set correctly
✅ Pod never restarts
✅ Pod terminates after 8 seconds
✅ Manual test job created and ran successfully

</details>

---

# ↩️ Restore Cluster State

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `reset_q04_baseline.sh` | Moving to next problem? Run this to remove all Q04 changes and restore clean cluster state |

---

### 🧹 Script : reset_q04_baseline.sh

**Done with this problem? Moving to the next one?**
Run this to remove all Q04 changes and restore a clean cluster state.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q04: CronJob - DNS Checker
# reset_q04_baseline.sh
# ============================================================

set -euo pipefail

NAMESPACE="cron-ops"

echo ""
echo "==========================================="
echo " CKAD Q04 — Restoring cluster to baseline..."
echo "==========================================="
echo ""

echo "[1/1] Deleting namespace '$NAMESPACE' (CronJob + Jobs + Pods)..."
kubectl delete namespace "$NAMESPACE" --ignore-not-found
echo "  Waiting for namespace deletion to complete..."
while kubectl get namespace "$NAMESPACE" &>/dev/null; do
  sleep 2
done
echo "  Namespace removed."

echo ""
echo "✅ Cluster is back to baseline!"
echo ""
echo "   Safe to move to next problem. 🚀"
echo ""
```

</details>

---