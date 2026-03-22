## 🧩 Problem Statement

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task; failure to do so may result in a score of **0**.

**Task:**

1. A Dockerfile exists at `/ckad/app-build/Dockerfile`. Use this Dockerfile to build a container image named `webapp` with the tag `2.1`. You can use any OCI-compliant tool available on the system (docker, podman, buildah, skopeo, img).
   > Do **NOT** push the built image to a registry, run the container, or use the image in any other way.

2. Export the built container image in **OCI format** and store it at `/ckad/app-build/webapp-2.1.tar`

</details>

---

## 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

**Step 1: Create directory and Dockerfile**

```bash
mkdir -p /ckad/app-build
```

```bash
cat <<EOF > /ckad/app-build/Dockerfile
FROM ubuntu:20.04
LABEL maintainer="devopstechtales"
RUN apt-get update && \
    apt-get install -y curl wget && \
    apt-get clean
WORKDIR /app
COPY . .
RUN echo "webapp v2.1" > /app/version.txt
CMD ["cat", "/app/version.txt"]
EOF
```

**Step 2: Verify Dockerfile exists**

```bash
cat /ckad/app-build/Dockerfile
```

Scenario is ready. ✅

</details>

---

## ✅ Solution

<details>
<summary>Click to expand the solution</summary>

---

### Step 1: Check the Dockerfile

```bash
cat /ckad/app-build/Dockerfile
```

---

### Step 2: Check which tools are available

```bash
which docker
which podman
which buildah
which skopeo
```

Use whichever tool is available. All approaches shown below.

---

### Option A: Using Docker (most common)

**Build the image:**

```bash
docker build -t webapp:2.1 /ckad/app-build/
```

**Verify image built:**

```bash
docker images | grep webapp
```

Output:
```
REPOSITORY   TAG   IMAGE ID       CREATED
webapp       2.1   abc123def456   10 seconds ago
```

**Export in OCI format:**

```bash
docker save webapp:2.1 -o /ckad/app-build/webapp-2.1.tar
```

**Verify tar file created:**

```bash
ls -lh /ckad/app-build/webapp-2.1.tar
```

---

### Option B: Using Podman

**Build the image:**

```bash
podman build -t webapp:2.1 /ckad/app-build/
```

**Verify image built:**

```bash
podman images | grep webapp
```

**Export in OCI format:**

```bash
podman save --format oci-archive \
  -o /ckad/app-build/webapp-2.1.tar \
  webapp:2.1
```

> `--format oci-archive` ensures OCI format — important for exam! ✅

---

### Option C: Using Buildah

**Build the image:**

```bash
buildah bud -t webapp:2.1 /ckad/app-build/
```

**Verify image built:**

```bash
buildah images | grep webapp
```

**Export in OCI format:**

```bash
buildah push webapp:2.1 \
  oci-archive:/ckad/app-build/webapp-2.1.tar
```

---

### Option D: Using Skopeo (copy from local to OCI)

> Skopeo cannot build images — use after building with docker or podman

```bash
# first build with docker or podman
docker build -t webapp:2.1 /ckad/app-build/

# then export with skopeo in OCI format
skopeo copy \
  docker-daemon:webapp:2.1 \
  oci-archive:/ckad/app-build/webapp-2.1.tar
```

---

### Final Verification (same for all tools)

```bash
# verify tar file exists and has size
ls -lh /ckad/app-build/webapp-2.1.tar

# verify it is valid OCI format
tar -tf /ckad/app-build/webapp-2.1.tar | head -10
```

Expected output:
```
-rw-r--r-- 1 root root 75M Mar 20 18:00 /ckad/app-build/webapp-2.1.tar
```

```
blobs/
blobs/sha256/
blobs/sha256/abc123...
index.json          ← OCI format indicator ✅
oci-layout          ← OCI format indicator ✅
```

✅ Image built successfully
✅ Exported in OCI format
✅ Stored at correct path

---

### Comparison table:

| Tool | Build command | Export OCI format |
|---|---|---|
| docker | `docker build -t name:tag .` | `docker save name:tag -o file.tar` |
| podman | `podman build -t name:tag .` | `podman save --format oci-archive -o file.tar name:tag` |
| buildah | `buildah bud -t name:tag .` | `buildah push name:tag oci-archive:/path/file.tar` |
| skopeo | cannot build | `skopeo copy docker-daemon:name:tag oci-archive:/path/file.tar` |


> In exam always use `podman save --format oci-archive` if podman is available — it guarantees pure OCI format! 💪

</details>

---