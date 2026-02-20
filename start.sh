#!/usr/bin/env bash
set -euo pipefail

NETWORK_NAME="nocodenation_playground_network"

echo "Ensuring Docker network '${NETWORK_NAME}' exists..."
if ! docker network inspect "${NETWORK_NAME}" &>/dev/null; then
  docker network create --driver bridge "${NETWORK_NAME}"
  echo "Network '${NETWORK_NAME}' created."
else
  echo "Network '${NETWORK_NAME}' already exists, skipping."
fi

echo "Copying compose.yml to tmp.compose.yml..."
cp compose.yml tmp.compose.yml

# Read PLATFORM from .env
PLATFORM_VAR=""
if [[ -f .env ]]; then
  PLATFORM_VAR=$(grep -E '^PLATFORM=' .env | cut -d'=' -f2 | tr -d '[:space:]')
fi

if [[ "${PLATFORM_VAR}" == "arm" || "${PLATFORM_VAR}" == "arm64" ]]; then
  DOCKER_PLATFORM="linux/arm64"
else
  DOCKER_PLATFORM="linux/amd64"
fi

echo "Setting platform to '${DOCKER_PLATFORM}' in tmp.compose.yml..."
sed -i "s|platform: linux/[a-z0-9/]*|platform: ${DOCKER_PLATFORM}|g" tmp.compose.yml

# Read USE_GPU from .env
USE_GPU_VAR=""
if [[ -f .env ]]; then
  USE_GPU_VAR=$(grep -E '^USE_GPU=' .env | cut -d'=' -f2 | tr -d '[:space:]')
fi

if [[ "${USE_GPU_VAR}" == "nvidia" ]]; then
  echo "Adding NVIDIA GPU configuration to ollama service..."
  awk '/^  ollama:/{
    print
    print "    deploy:"
    print "      resources:"
    print "        reservations:"
    print "          devices:"
    print "            - driver: nvidia"
    print "              count: all"
    print "              capabilities: [gpu]"
    next
  }
  { print }' tmp.compose.yml > tmp.compose.yml.tmp && mv tmp.compose.yml.tmp tmp.compose.yml
fi

echo "Starting services..."
docker compose -f tmp.compose.yml up -d

echo "Access Open-WebUI at:"
echo "http://localhost:8200"
