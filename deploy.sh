#!/bin/bash
set -e

# ============================================================
# Shared Deploy Script for Chartwell/TTG Games
# Called from bitbucket-pipelines.yml in each game repo
#
# Required env vars:
#   DEPLOY_PATH - e.g. /home/game/resin/webapps
# ============================================================

WAR_NAME=$(grep -m1 '<artifactId>' server/pom.xml | sed 's/.*<artifactId>//;s/<.*//' | tr -d '[:space:]')

echo "=== Deploying ${WAR_NAME}.war ==="
cp game.war "${DEPLOY_PATH}/${WAR_NAME}.war"
chown game:game "${DEPLOY_PATH}/${WAR_NAME}.war" 2>/dev/null || true
echo "=== SUCCESS - ${WAR_NAME}.war deployed ==="
