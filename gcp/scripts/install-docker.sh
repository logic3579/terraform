#!/bin/bash
set -euo pipefail

# Docker installation script for Ubuntu 24.04
# This script installs Docker CE with a specific version

echo "Starting Docker installation..."

# Update package index
apt-get update

# Install prerequisites
apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up the Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index with Docker packages
apt-get update

# Install specific Docker version
VERSION_STRING="5:28.5.2-1~ubuntu.24.04~noble"
apt-get install -y \
  docker-ce=$VERSION_STRING \
  docker-ce-cli=$VERSION_STRING \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# Hold Docker packages to prevent automatic updates
apt-mark hold docker-ce docker-ce-cli

# Enable and start Docker service
systemctl enable --now docker

echo "Docker installation completed successfully"
echo "Docker version: $(docker --version)"
