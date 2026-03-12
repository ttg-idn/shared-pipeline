#!/bin/bash
set -e

# ============================================================
# Shared Deploy Script for Chartwell/TTG Games
# Called from bitbucket-pipelines.yml in each game repo
#
# Required env vars:
#   DEPLOY_PATH   - e.g. /home/game/resin/webapps
#   STAGING_HOST  - e.g. 10.4.111.42
#   DEPLOY_USER   - e.g. ec2-user
#   SSH_KEY        - private SSH key (base64 encoded)
# ============================================================

WAR_NAME=$(grep -m1 '<artifactId>' server/pom.xml | sed 's/.*<artifactId>//;s/<.*//' | tr -d '[:space:]')

echo "=== Setting up SSH ==="
mkdir -p ~/.ssh
echo "$SSH_KEY" | base64 -d > ~/.ssh/deploy_key
chmod 600 ~/.ssh/deploy_key
ssh-keyscan -H "${STAGING_HOST}" >> ~/.ssh/known_hosts 2>/dev/null

echo "=== Deploying ${WAR_NAME}.war to ${STAGING_HOST} ==="
scp -i ~/.ssh/deploy_key game.war "${DEPLOY_USER}@${STAGING_HOST}:${DEPLOY_PATH}/${WAR_NAME}.war"
echo "=== SUCCESS - ${WAR_NAME}.war deployed to ${STAGING_HOST}:${DEPLOY_PATH} ==="
