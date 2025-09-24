#!/bin/bash

FRONTEND_MAP_FILE="/home/ubuntu/scripts/frontend-port-map.txt"
BACKEND_MAP_FILE="/home/ubuntu/scripts/backend-port-map.txt"
DEFAULT_BACKEND_PORT=3333
DEFAULT_FRONTEND_PORT=3000

# Function to slugify text
slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9-]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//'
}

# Function to find frontend port
find_frontend_port() {
  local subdomain=$1
  if [ -f "$FRONTEND_MAP_FILE" ] && [ -s "$FRONTEND_MAP_FILE" ]; then
    while IFS=' ' read -r port mapped_subdomain; do
      if [ "$mapped_subdomain" = "$subdomain" ]; then
        echo "$port"
        return
      fi
    done <"$FRONTEND_MAP_FILE"
  fi
  echo "$DEFAULT_FRONTEND_PORT"
}

# Function to find backend port
find_backend_port() {
  local subdomain=$1
  if [ -f "$BACKEND_MAP_FILE" ] && [ -s "$BACKEND_MAP_FILE" ]; then
    while IFS=' ' read -r port mapped_subdomain; do
      if [ "$mapped_subdomain" = "$subdomain" ]; then
        echo "$port"
        return
      fi
    done <"$BACKEND_MAP_FILE"
  fi
  echo ""
}

# Function to get next available port
get_next_available_port() {
  if [ ! -f "$BACKEND_MAP_FILE" ] || [ ! -s "$BACKEND_MAP_FILE" ]; then
    echo "$DEFAULT_BACKEND_PORT"
    return
  fi
  local last_port=$(tail -n 1 "$BACKEND_MAP_FILE" | awk '{print $1}')
  echo $((last_port + 1))
}

# Function to assign backend port
assign_backend_port() {
  local subdomain=$1
  local existing_port=$(find_backend_port "$subdomain")
  if [ -n "$existing_port" ]; then
    echo "$existing_port"
    return
  fi
  local new_port=$(get_next_available_port)
  echo "$new_port $subdomain" >>"$BACKEND_MAP_FILE"
  echo "$new_port"
}

# Function to create nginx config
create_nginx_config() {
  local subdomain=$1
  local frontend_port=$(find_frontend_port "$subdomain")
  local backend_port=$(find_backend_port "$subdomain")
  local file_name="${subdomain}.ecstaging.org"
  local config_path="/etc/nginx/sites-available/$file_name"

  # Create nginx config file content
  cat >"$config_path" <<EOF
server {
    listen 443 ssl;
    server_name $file_name;
    ssl_certificate /etc/letsencrypt/live/ecstaging.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ecstaging.org/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        proxy_pass http://localhost:$frontend_port/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    location /api/ {
        rewrite ^/api/(.*) /\$1 break;
        proxy_pass http://localhost:$backend_port/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    location /ezy-scorm-files/ {
        proxy_pass https://staticwebsitesforezy.blob.core.windows.net/;
        proxy_http_version 1.1;
        proxy_set_header Host "staticwebsitesforezy.blob.core.windows.net";
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

  # Create symbolic link
  ln -s "$config_path" "/etc/nginx/sites-enabled/"

  # Test and reload nginx
  nginx -t && systemctl reload nginx
}

# Main function
main() {
  local subdomain=$(slugify "${1:-}")
  if [ -z "$subdomain" ]; then
    echo "Subdomain is empty."
    exit 1
  fi

  local assigned_port=$(assign_backend_port "$subdomain")
  local frontend_port=$(find_frontend_port "$subdomain")

  create_nginx_config "$subdomain"

  echo "Script completed successfully."
  echo "Subdomain: $subdomain"
  echo "Frontend Port: $frontend_port"
  echo "Backend Port: $assigned_port"
}

# Run main function with first command-line argument
main "$1"