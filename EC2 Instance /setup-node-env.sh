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

echo "Node.js, pnpm, and pm2 setup completed!"
