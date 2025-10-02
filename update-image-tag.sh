#!/bin/bash
# Script to update image tags and trigger deployment via webhook
set -e

# Usage: ./update-image-tag.sh <environment> <new-tag>
# Example: ./update-image-tag.sh dev main-abc123

ENVIRONMENT=${1:-dev}
NEW_TAG=${2}

if [ -z "$NEW_TAG" ]; then
  echo "Usage: $0 <environment> <new-tag>"
  echo "Example: $0 dev main-abc123"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================"
echo "🏷️  IMAGE TAG UPDATE"
echo "========================================"
echo "Environment: $ENVIRONMENT"
echo "New tag: $NEW_TAG"
echo ""

# Determine values file
VALUES_FILE="charts/core-pipeline/values-${ENVIRONMENT}.yaml"

if [ ! -f "$VALUES_FILE" ]; then
  echo "❌ Error: Values file not found: $VALUES_FILE"
  exit 1
fi

echo "=== 1. Update image tag in $VALUES_FILE ==="

# Update the image tag using sed
# This assumes the values file has a structure like:
# image:
#   tag: "main-abc123"
sed -i.bak "s|tag: \".*\"|tag: \"$NEW_TAG\"|g" "$VALUES_FILE"

# Show the change
echo "Updated line:"
grep "tag:" "$VALUES_FILE" || echo "Warning: Could not find 'tag:' in values file"
echo ""

# Remove backup file
rm -f "${VALUES_FILE}.bak"

echo "=== 2. Commit and push changes ==="
git add "$VALUES_FILE"
git commit -m "chore(${ENVIRONMENT}): update image tag to ${NEW_TAG}"
git push origin main

echo ""
echo "========================================"
echo "✅ IMAGE TAG UPDATED"
echo "========================================"
echo ""
echo "The GitHub webhook will now trigger deployment automatically."
echo "Monitor the deployment with:"
echo "  kubectl get pods -n ${ENVIRONMENT}-core -w"
echo ""
