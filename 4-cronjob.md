## 🧩 Problem Statement

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task; failure to do so may result in a score of **0**.

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

## 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

**Step 1: Create namespace**

```bash
kubectl create namespace cron-ops
```

Scenario is ready — just need to create the CronJob from scratch. ✅

</details>

---

## ✅ Solution

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