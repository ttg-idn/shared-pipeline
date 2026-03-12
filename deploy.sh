#!/bin/bash
set -e

# ============================================================
# Shared Deploy Script for Chartwell/TTG Games
#
# Usage: bash deploy.sh [HOST_VAR]
#   HOST_VAR - env variable name containing target host IP
#              defaults to STAGING_HOST
#
# Examples:
#   bash deploy.sh                  -> deploys to $STAGING_HOST
#   bash deploy.sh PREPROD_HOST_1   -> deploys to $PREPROD_HOST_1
#   bash deploy.sh PROD_HOST_1      -> deploys to $PROD_HOST_1
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

echo "=== Deploying ${WAR_NAME}.war to ${TARGET_HOST} (${HOST_VAR}) ==="
scp -i ~/.ssh/deploy_key game.war "${DEPLOY_USER}@${TARGET_HOST}:${DEPLOY_PATH}/${WAR_NAME}.war"
echo "=== SUCCESS - ${WAR_NAME}.war deployed to ${TARGET_HOST}:${DEPLOY_PATH} ==="
