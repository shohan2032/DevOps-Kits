#!/bin/bash
PATH="/home/ubuntu/.nvm/versions/node/v20.9.0/bin:$PATH"
BACKEND_BASE_PATH="/home/ubuntu/backend"
FRONTEND_BASE_PATH="/home/ubuntu/frontend"

# Combined trap command
trap 'rm -f "${FRONTEND_BASE_PATH}/reloading.txt" "${BACKEND_BASE_PATH}/reloading.txt"' EXIT

# Function to calculate memory usage percentage
calculate_memory_usage() {
  total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  free_memory=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
  used_memory=$((total_memory - free_memory))
  memory_usage_percentage=$(((used_memory * 100) / total_memory))
  echo $memory_usage_percentage
}

memory_usage=$(calculate_memory_usage)

if [ "$memory_usage" -ge 72 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Memory usage is at ${memory_usage}%, initiating reloads..."

  # Backend reload
  if [ -f "$BACKEND_BASE_PATH/reloading.txt" ]; then
    echo "Backend is already in reloading state, skipping..."
  else
    echo "Reloading backend..." >"$BACKEND_BASE_PATH/reloading.txt"
    if pm2 reload web-app; then
      echo "Backend reloaded successfully"
    else
      echo "Backend reload failed"
    fi
  fi

  # Frontend reload - independent of backend status
  if [ -f "$FRONTEND_BASE_PATH/reloading.txt" ]; then
    echo "Frontend is already in reloading state, skipping..."
  else
    echo "Reloading frontend..." >"$FRONTEND_BASE_PATH/reloading.txt"
    if pm2 reload frontend; then
      echo "Frontend reloaded successfully"
    else
      echo "Frontend reload failed"
    fi
  fi

  echo "$(date '+%Y-%m-%d %H:%M:%S') - Script ecxecution completed"
fi