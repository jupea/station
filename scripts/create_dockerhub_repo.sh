#!/bin/bash

set -euo pipefail


# Validate required environment variables
if [[ -z "${DOCKERHUB_USERNAME:-}" ]]; then
  echo "ERROR: DOCKERHUB_USERNAME environment variable is not set" >&2
  exit 1
fi

if [[ -z "${DOCKERHUB_TOKEN:-}" ]]; then
  echo "ERROR: DOCKERHUB_TOKEN environment variable is not set" >&2
  exit 1
fi

if [[ -z "${DOCKER_REPO:-}" ]]; then
  echo "ERROR: DOCKER_REPO environment variable is not set" >&2
  exit 1
fi

NAMESPACE="${DOCKERHUB_USERNAME}"
REPOSITORY="${DOCKER_REPO}"
REGISTRY_URL="https://hub.docker.com/v2"

# Create Bearer token from username and token
AUTH_HEADER=$(echo -n "${DOCKERHUB_USERNAME}:${DOCKERHUB_TOKEN}" | base64 -w 0)

echo "Checking if repository '${NAMESPACE}/${REPOSITORY}' exists..."

# Check if repository exists using HEAD request
if curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Basic ${AUTH_HEADER}" \
  "https://hub.docker.com/v2/namespaces/${NAMESPACE}/repositories/${REPOSITORY}/tags" \
  | grep -q "404"; then
  
  echo "Repository does not exist. Creating '${NAMESPACE}/${REPOSITORY}'..."
  
  # Create the repository
  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: Basic ${AUTH_HEADER}" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"${REPOSITORY}\",
      \"namespace\": \"${NAMESPACE}\",
      \"description\": \"Docker repository for ${REPOSITORY}\",
      \"full_description\": \"This is a Docker repository for ${REPOSITORY} application.\",
      \"registry\": \"docker.io\",
      \"is_private\": false
    }" \
    "${REGISTRY_URL}/namespaces/${NAMESPACE}/repositories")
  
  # Extract HTTP status code (last line)
  HTTP_CODE=$(echo "${RESPONSE}" | tail -n 1)
  # Extract response body (all but last line)
  RESPONSE_BODY=$(echo "${RESPONSE}" | head -n -1)
  
  if [[ "${HTTP_CODE}" == "201" ]]; then
    echo "✓ Repository '${NAMESPACE}/${REPOSITORY}' created successfully!"
    echo "Repository details:"
    echo "${RESPONSE_BODY}" | jq '.' 2>/dev/null || echo "${RESPONSE_BODY}"
  else
    echo "✗ Failed to create repository. HTTP Status: ${HTTP_CODE}" >&2
    echo "Response: ${RESPONSE_BODY}" >&2
    exit 1
  fi
else
  echo "✓ Repository '${NAMESPACE}/${REPOSITORY}' already exists."
fi

