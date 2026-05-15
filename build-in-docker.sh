#!/bin/bash
set -e

# ============================================================
# Shared Build-in-Docker Wrapper for Chartwell/TTG Games
# ============================================================
# Runs `bash shared-pipeline/build.sh` inside a maven:3.6.3-jdk-8
# Docker container with a *persistent* Maven local repository
# mounted from the runner host. This removes the cold-cache
# 20+ minute timeout that game CIs were hitting (PoD CI cancelled
# 3× on 2026-05-13 — each Docker run was redownloading ~hundreds
# of MB from Nexus, even though Nexus is on the same LAN).
#
# Game workflows used to inline a one-line `docker run` per repo
# with no volume for the Maven cache, so every CI build started
# with /root/.m2/repository empty. After this wrapper lands and
# each game workflow switches to calling it, the host directory
# /home/<runner-user>/m2-cache/<runner>-<repo> survives across
# runs and the second+ build of any game reuses cached deps.
#
# Per-repo subdirectory keeps caches isolated to prevent races
# if the runner is later scaled to multi-slot. Permissions reset
# (chown to the runner user) at the end so the GH Actions cleanup
# step can rm the workspace without sudo.
#
# Expected env (set by the calling workflow):
#   NEXUS_URL — Nexus group URL the inner build.sh wires into
#               its generated pipeline-settings.xml.
#
# Inputs:
#   $1 (optional) — extra args passed through to the inner
#                   `bash shared-pipeline/build.sh` invocation.

WORKSPACE="${GITHUB_WORKSPACE:-$PWD}"
REPO="${GITHUB_REPOSITORY##*/}"
RUNNER_USER="$(id -un)"
RUNNER_UID="$(id -u)"
RUNNER_GID="$(id -g)"

CACHE_BASE="/home/${RUNNER_USER}/m2-cache"
CACHE_DIR="${CACHE_BASE}/${REPO:-default}"
mkdir -p "${CACHE_DIR}"

echo "=== build-in-docker.sh ==="
echo "Workspace:        ${WORKSPACE}"
echo "Repo:             ${REPO}"
echo "Maven cache dir:  ${CACHE_DIR}"
echo "Nexus URL:        ${NEXUS_URL}"

# BEGINNING-OF-BUILD chown: scrub any root-owned residue left behind by
# previous docker runs that predated this wrapper (i.e. before commit 99dfefd).
# On 2026-05-14/15 every game CI (PoD, RGD, MegaPhoenix, IMK, SantaV, WildWestH5)
# failed actions/checkout@v4 with EACCES rmdir on .../target/antrun because the
# container ran as root. The END-OF-BUILD chown below stops new accumulation;
# this START-OF-BUILD chown evicts the legacy residue so checkout can clean.
sudo -n chown -R "${RUNNER_UID}:${RUNNER_GID}" "${WORKSPACE}" 2>/dev/null || true
sudo -n chown -R "${RUNNER_UID}:${RUNNER_GID}" "${CACHE_DIR}" 2>/dev/null || true

docker run --rm \
  -v "${WORKSPACE}:/workspace" \
  -v "${CACHE_DIR}:/root/.m2/repository" \
  -w /workspace \
  -e NEXUS_URL="${NEXUS_URL}" \
  maven:3.6.3-jdk-8 \
  bash -c "bash shared-pipeline/build.sh $1 && chown -R ${RUNNER_UID}:${RUNNER_GID} /workspace && chown -R ${RUNNER_UID}:${RUNNER_GID} /root/.m2/repository"

# Defensive: the chown above runs inside the container against
# /root/.m2/repository (mounted from CACHE_DIR), so the host dir
# should already be runner-owned. Reassert outside in case Docker
# layered mount semantics drop the chown for any path.
if [ -d "${CACHE_DIR}" ]; then
  find "${CACHE_DIR}" -not -user "${RUNNER_USER}" -exec sudo -n chown "${RUNNER_UID}:${RUNNER_GID}" {} + 2>/dev/null || true
fi

echo "=== build-in-docker.sh complete ==="
