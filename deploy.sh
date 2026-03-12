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
sudo cp game.war "${DEPLOY_PATH}/${WAR_NAME}.war"
sudo chown game:game "${DEPLOY_PATH}/${WAR_NAME}.war"
echo "=== SUCCESS - ${WAR_NAME}.war deployed ==="
