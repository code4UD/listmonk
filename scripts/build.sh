#!/bin/bash

# Script de build pour listmonk-mairies
set -e

echo "🏗️  Building listmonk-mairies..."

# Vérifier que Docker est disponible
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is required but not installed."
    exit 1
fi

# Variables
IMAGE_NAME="listmonk-mairies"
VERSION="v1.0.0"
BUILD_DATE=$(date -u +%Y%m%d.%H%M%S)

echo "📦 Building Docker image..."
docker build \
    -f Dockerfile.mairies \
    -t ${IMAGE_NAME}:${VERSION} \
    -t ${IMAGE_NAME}:latest \
    --build-arg BUILD_DATE=${BUILD_DATE} \
    --build-arg VERSION=${VERSION} \
    .

echo "✅ Build completed successfully!"
echo "🐳 Image: ${IMAGE_NAME}:${VERSION}"
echo "📅 Build date: ${BUILD_DATE}"

# Afficher la taille de l'image
echo "📊 Image size:"
docker images ${IMAGE_NAME}:${VERSION} --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

echo ""
echo "🚀 To run the application:"
echo "   docker-compose -f docker-compose.mairies.yml up -d"
echo ""
echo "🔧 To run in development mode:"
echo "   docker-compose -f docker-compose.mairies.yml --profile dev up -d"