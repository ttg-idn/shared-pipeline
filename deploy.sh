#!/bin/bash
set -e

# ============================================================
# Shared Deploy Script for Chartwell/TTG Games
#
# Usage: bash deploy.sh [HOST_VAR]
#   HOST_VAR - env variable name containing target host IP
#              defaults to STAGING_HOST
#
# Required env vars:
#   DEPLOY_PATH   - e.g. /home/game/resin/webapps
#   DEPLOY_USER   - e.g. ec2-user
#   SSH_KEY       - private SSH key (base64 encoded)
#   <HOST_VAR>    - target host IP
# ============================================================

HOST_VAR="${1:-STAGING_HOST}"
TARGET_HOST="${!HOST_VAR}"

if [ -z "$TARGET_HOST" ]; then
  echo "ERROR - Variable $HOST_VAR is not set"
  exit 1
fi

WAR_NAME=$(grep -m1 '<artifactId>' server/pom.xml | sed 's/.*<artifactId>//;s/<.*//' | tr -d '[:space:]')

echo "=== Setting up SSH ==="
mkdir -p ~/.ssh
echo "$SSH_KEY" | base64 -d > ~/.ssh/deploy_key
chmod 600 ~/.ssh/deploy_key
ssh-keyscan -H "${TARGET_HOST}" >> ~/.ssh/known_hosts 2>/dev/null

SSH_CMD="ssh -i ~/.ssh/deploy_key ${DEPLOY_USER}@${TARGET_HOST}"
SCP_CMD="scp -i ~/.ssh/deploy_key"

echo "=== Uploading ${WAR_NAME}.war to ${TARGET_HOST}:/tmp ==="
# Remove old WAR from /tmp (may have root ownership from previous deploy)
$SSH_CMD "sudo rm -f /tmp/${WAR_NAME}.war" 2>/dev/null || true
$SCP_CMD game.war "${DEPLOY_USER}@${TARGET_HOST}:/tmp/${WAR_NAME}.war"

echo "=== Creating backup ==="
BACKUP_TS=$(date +%Y%m%d_%H%M%S)
# NOTE: the deploy dir (e.g. /home/game/resin/webapps) lives under /home/game,
# which is mode 700 owned by 'game'. DEPLOY_USER (ec2-user) cannot traverse it,
# so a plain `[ -f ... ]` test ALWAYS returned false and the backup was never
# created. Run the existence test + cleanup via sudo so root can see the dir.
$SSH_CMD "
  if sudo test -f ${DEPLOY_PATH}/${WAR_NAME}.war; then
    sudo cp ${DEPLOY_PATH}/${WAR_NAME}.war ${DEPLOY_PATH}/${WAR_NAME}.war.bak.${BACKUP_TS}
    sudo chown game:game ${DEPLOY_PATH}/${WAR_NAME}.war.bak.${BACKUP_TS}
    echo 'Backup created: ${WAR_NAME}.war.bak.${BACKUP_TS}'
    # keep the last 3 backups (run as root so it can read the game-owned dir)
    sudo bash -c 'ls -1t ${DEPLOY_PATH}/${WAR_NAME}.war.bak.* 2>/dev/null | tail -n +4 | xargs -r rm -f'
  else
    echo 'No existing WAR to backup'
  fi
"

echo "=== Moving to ${DEPLOY_PATH} ==="
$SSH_CMD "sudo cp /tmp/${WAR_NAME}.war ${DEPLOY_PATH}/${WAR_NAME}.war && sudo chown game:game ${DEPLOY_PATH}/${WAR_NAME}.war && rm /tmp/${WAR_NAME}.war"

echo "=== SUCCESS - ${WAR_NAME}.war deployed to ${TARGET_HOST}:${DEPLOY_PATH} ==="
