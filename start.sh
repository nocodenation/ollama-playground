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

  echo "Switching speaches image to latest-cuda..."
  sed -i "s|ghcr.io/speaches-ai/speaches:latest-cpu|ghcr.io/speaches-ai/speaches:latest-cuda|g" tmp.compose.yml

  echo "Adding NVIDIA GPU configuration to speaches service..."
  awk '/^  speaches:/{
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

MODEL_CACHE_VOLUME="./volumes/speaches/hf_hub_cache"

if [[ -d "${MODEL_CACHE_VOLUME}" ]]; then
  echo "Persisted volume ${MODEL_CACHE_VOLUME} already exists. Skipping creation"
else
  mkdir -p ./volumes/speaches/hf_hub_cache
  chmod -R 777 ./volumes/speaches/hf_hub_cache
  chown -R 1000:1000 ./volumes/speaches/hf_hub_cache

  MODEL_CACHE_DIR="./volumes/speaches/hf_hub_cache/hub/models--JhonVanced--faster-whisper-large-v3"
  if [[ -d "${MODEL_CACHE_DIR}" ]]; then
    echo "Model JhonVanced/faster-whisper-large-v3 already downloaded, skipping."
  else
    if [[ "${USE_GPU_VAR}" == "nvidia" ]]; then
      SPEACHES_IMAGE="ghcr.io/speaches-ai/speaches:latest-cuda"
    else
      SPEACHES_IMAGE="ghcr.io/speaches-ai/speaches:latest-cpu"
    fi
    echo "Pre-downloading JhonVanced/faster-whisper-large-v3 using ${SPEACHES_IMAGE}..."
    docker run --rm \
      -v "$(pwd)/volumes/speaches/hf_hub_cache:/home/ubuntu/.cache/huggingface:z" \
      "${SPEACHES_IMAGE}" \
      huggingface-cli download JhonVanced/faster-whisper-large-v3
  fi
fi

echo "Starting services..."
docker compose -f tmp.compose.yml up -d

echo ""
echo "Access Open-WebUI at:"
echo "http://localhost:8200"
echo ""
echo "Direct access to Ollama is avaliabla at"
echo "http://localhost:8201"
echo ""
echo "Access voice recognition tool at:"
echo "http://localhost:8202"
