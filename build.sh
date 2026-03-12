#!/bin/bash
set -e

# ============================================================
# Shared Build Script for Chartwell/TTG Games
# Called from bitbucket-pipelines.yml in each game repo
# ============================================================

echo "=== Configuring Maven settings ==="
echo "<settings>
  <mirrors>
    <mirror>
      <id>nexus</id>
      <mirrorOf>*</mirrorOf>
      <url>${NEXUS_URL}</url>
    </mirror>
  </mirrors>
  <profiles>
    <profile>
      <id>nexus</id>
      <repositories>
        <repository>
          <id>central</id>
          <url>http://central</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
      </repositories>
    </profile>
  </profiles>
  <activeProfiles>
    <activeProfile>nexus</activeProfile>
  </activeProfiles>
</settings>" > /tmp/pipeline-settings.xml

echo "=== Building WAR ==="
mvn clean install -U \
  -DskipTests \
  -Dmaven.buildNumber.doCheck=false \
  -Dmaven.compiler.source=1.7 \
  -Dmaven.compiler.target=1.7 \
  -s /tmp/pipeline-settings.xml

WAR_FILE=$(ls server/target/*.war 2>/dev/null | head -1)
if [ -z "$WAR_FILE" ]; then
  echo "ERROR - No WAR file found in server/target/"
  exit 1
fi

echo "Built WAR - $WAR_FILE"
cp "$WAR_FILE" game.war
echo "=== Build complete ==="
