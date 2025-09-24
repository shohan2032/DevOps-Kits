#!/bin/bash

# Delete staging

# Get subdomain name from first argument
subdomain=$1

# Check if subdomain is provided
if [ -z "$subdomain" ]; then
  echo "Error: Subdomain not provided"
  echo "Usage: $0 <subdomain>"
  exit 1
fi

export NVM_DIR=~/.nvm
source ~/.nvm/nvm.sh || true

# Remove the release directory
rm -rf "/home/ubuntu/frontend/releases/$subdomain"

# Delete the PM2 process
pm2 delete "frontend-$subdomain" || true

# Delete the line with the subdomain from the port map file
sed -i "/[[:space:]]$subdomain$/d" /home/ubuntu/scripts/frontend-port-map.txt

# Remove the NGINX configuration file
sudo rm "/etc/nginx/sites-available/$subdomain.ecstaging.org"
sudo rm "/etc/nginx/sites-enabled/$subdomain.ecstaging.org"

# Reload NGINX to apply changes
sudo nginx -t && sudo systemctl reload nginx && echo "NGINX reloaded"

echo "Cleanup for $subdomain completed"