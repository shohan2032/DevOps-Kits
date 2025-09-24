#!/bin/bash
set -e

# Update system
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y curl build-essential libssl-dev

# Install NVM
export NVM_VERSION="v0.39.7"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | bash

# Load NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Node.js LTS
nvm install --lts

# Install pnpm globally
npm install -g pnpm

# Install pm2 globally using pnpm
pnpm add -g pm2

# Install Nginx
sudo apt install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx

echo "Node.js, pnpm, pm2, and Nginx setup completed!"

# Display installed versions
echo "Node.js version: $(node -v)"
echo "pnpm version: $(pnpm -v)"
echo "pm2 version: $(pm2 -v)"
echo "Nginx version: $(nginx -v)"