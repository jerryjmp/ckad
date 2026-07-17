# 🧩 Problem Statement (Build & Export Image in OCI Format)

<details>
<summary>Click to expand the problem statement</summary>

A Kubernetes cluster is already configured. You must connect to the **correct context** before attempting the task; failure to do so may result in a score of **0**.

**Task:**

1. A Dockerfile exists at `/ckad/app-build/Dockerfile`. Use this Dockerfile to build a container image named `webapp` with the tag `2.1`. You can use any OCI-compliant tool available on the system (docker, podman, buildah, skopeo, img).
   > Do **NOT** push the built image to a registry, run the container, or use the image in any other way.

2. Export the built container image in **OCI format** and store it at `/ckad/app-build/webapp-2.1.tar`

</details>

---

# 🛠 Setup Practice Scenario

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `setup_q14_problem_scenario.sh` | Writes the Dockerfile to `/ckad/app-build/` — run before practice (re-run anytime to practice again) |

---

### 📥 Script : setup_q14_problem_scenario.sh

Run this **before you start practicing** this problem.
Re-run anytime you want to practice again after fixing.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q14: Build & Export Image in OCI Format
# setup_q14_problem_scenario.sh
# Writes Dockerfile only — no image built, no tar exported yet
# Run on: controlplane node (or wherever docker/podman/buildah lives)
# ============================================================

set -euo pipefail

BUILD_DIR="/ckad/app-build"
IMAGE_NAME="webapp"
IMAGE_TAG="2.1"
TAR_FILE="$BUILD_DIR/webapp-2.1.tar"

echo ""
echo "==========================================="
echo " CKAD Q14 — Setting up Image Build scenario..."
echo "==========================================="
echo ""

# ── Step 0: Revert solution-specific changes (fast) ────────────
# Only undoes what THIS question's solution produces:
# - the built webapp:2.1 image (in whichever tool's local store)
# - the exported webapp-2.1.tar file
# The Dockerfile itself is rewritten fresh in Step 2 regardless.
echo "[0/2] Reverting any previous solution changes..."

if command -v docker &>/dev/null; then
  docker rmi "${IMAGE_NAME}:${IMAGE_TAG}" &>/dev/null || true
fi
if command -v podman &>/dev/null; then
  podman rmi "${IMAGE_NAME}:${IMAGE_TAG}" &>/dev/null || true
fi
if command -v buildah &>/dev/null; then
  buildah rmi "${IMAGE_NAME}:${IMAGE_TAG}" &>/dev/null || true
fi

rm -f "$TAR_FILE"
echo "  Reverted (built image and tar file removed, if present)."

# ── Step 1: Create directory ────────────────────────────────────
echo "[1/2] Ensuring build directory exists..."
sudo mkdir -p "$BUILD_DIR"
sudo chown "$(id -u):$(id -g)" "$BUILD_DIR"
echo "  Directory ready."

# ── Step 2: Write the Dockerfile ─────────────────────────────────
echo "[2/2] Writing Dockerfile..."

cat <<EOF > "$BUILD_DIR/Dockerfile"
FROM ubuntu:20.04
LABEL maintainer="devopstechtales"
RUN apt-get update && \\
    apt-get install -y curl wget && \\
    apt-get clean
WORKDIR /app
COPY . .
RUN echo "webapp v2.1" > /app/version.txt
CMD ["cat", "/app/version.txt"]
EOF

echo "  Dockerfile written."
cat "$BUILD_DIR/Dockerfile"

echo ""
echo "✅ Q14 scenario is ready!"
echo ""
echo "   Dockerfile at: $BUILD_DIR/Dockerfile"
echo "   No image built, no tar exported yet."
echo "   Now go build it! 💪"
echo ""
```

</details>

---

# ✅ Solution

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

**Export the image:**

```bash
docker save webapp:2.1 -o /ckad/app-build/webapp-2.1.tar
```

> ⚠️ `docker save` writes Docker's own archive format, **not** true OCI format. If the exam grader strictly checks for `oci-layout`/`index.json` inside the tar, prefer Option B (podman) or Option D (skopeo) below.

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

> `--format oci-archive` ensures true OCI format — important for exam! ✅

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

# then export with skopeo in true OCI format
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
| docker | `docker build -t name:tag .` | `docker save name:tag -o file.tar` *(Docker archive, not true OCI)* |
| podman | `podman build -t name:tag .` | `podman save --format oci-archive -o file.tar name:tag` |
| buildah | `buildah bud -t name:tag .` | `buildah push name:tag oci-archive:/path/file.tar` |
| skopeo | cannot build | `skopeo copy docker-daemon:name:tag oci-archive:/path/file.tar` |

> In exam always use `podman save --format oci-archive` if podman is available — it guarantees pure OCI format! 💪

</details>

---

# ↩️ Restore Cluster State

<details>
<summary>Click to expand setup steps</summary>

| Script | Purpose |
|--------|---------|
| `reset_q14_baseline.sh` | Moving to next problem? Run this to remove all Q14 changes and restore clean cluster state |

---

### 🧹 Script : reset_q14_baseline.sh

**Done with this problem? Moving to the next one?**
Run this to remove all Q14 changes and restore a clean cluster state.

```bash
#!/bin/bash
# ============================================================
# CKAD Practice | Q14: Build & Export Image in OCI Format
# reset_q14_baseline.sh
# ============================================================

set -euo pipefail

BUILD_DIR="/ckad/app-build"
IMAGE_NAME="webapp"
IMAGE_TAG="2.1"

echo ""
echo "==========================================="
echo " CKAD Q14 — Restoring cluster to baseline..."
echo "==========================================="
echo ""

echo "[1/2] Removing built image (if present) from all tools..."
if command -v docker &>/dev/null; then
  docker rmi "${IMAGE_NAME}:${IMAGE_TAG}" &>/dev/null || true
fi
if command -v podman &>/dev/null; then
  podman rmi "${IMAGE_NAME}:${IMAGE_TAG}" &>/dev/null || true
fi
if command -v buildah &>/dev/null; then
  buildah rmi "${IMAGE_NAME}:${IMAGE_TAG}" &>/dev/null || true
fi
echo "  Images removed."

echo "[2/2] Removing build directory..."
sudo rm -rf "$BUILD_DIR"
echo "  Build directory removed."

echo ""
echo "✅ Cluster is back to baseline!"
echo ""
echo "   Safe to move to next problem. 🚀"
echo ""
```

</details>

---