#!/bin/bash


# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <server_number> (e.g. $0 1)"
    exit 1
fi

# Function to check if a string is a positive integer
is_positive_integer() {
    [[ $1 =~ ^[1-9][0-9]*$ ]]
}

# Check if the argument is a positive integer
if ! is_positive_integer "$1"; then
    echo "Error: invalid server number. Please provide a positive integer. (e.g. 1 or 2)"
    exit 1
fi

# Log file path
log_file="/home/ubuntu/log/system/system-info.log"

# Function to log messages with timestamp
log_message() {
    echo "$(date +"%Y-%m-%d %T") $1" >> "$log_file"
}

# Function to log errors with timestamp
log_error() {
    log_message "Error: $1"
}

# Check if log file exists and is writable
if [ ! -f "$log_file" ] || [ ! -w "$log_file" ]; then
    echo "Log file doesn't exist or is not writable."
    exit 1
fi

# Gather server information
memory_total=$(free -m | awk 'NR==2{print $2}') || { log_error "Failed to get memory information."; }
memory_used=$(free -m | awk 'NR==2{print $3}') || { log_error "Failed to get memory information."; }
memory_free=$(free -m | awk 'NR==2{print $4}') || { log_error "Failed to get memory information."; }
memory_usage="$memory_used MB / $memory_total MB"
memory_free="$memory_free MB"

# Get storage information
storage_info=$(df -h / | awk 'NR==2{print $2,$3,$4}') || { log_error "Failed to get storage information."; }
read -r storage_total storage_used storage_free <<< "$storage_info"
storage_usage="$storage_used / $storage_total"

# Determine server number from argument
server_number="$1"

# Construct JSON object for payload
payload='{
  "dataSource": "dedicatedinstance",
  "database": "amaderasoldbmongo",
  "collection": "server_info",
  "document": {
    "memory_usage": "'"$memory_usage"'",
    "free_memory": "'"$memory_free"'",
    "storage_usage": "'"$storage_usage"'",
    "free_storage_space": "'"$storage_free"'",
    "server": '$server_number',
    "created_at": {
      "$date": {
        "$numberLong": "'$(date +"%s")'000"
      }
    }
  }
}'

# Define MongoDB Data API endpoint
api_endpoint="https://ap-south-1.aws.data.mongodb-api.com/app/data-edsec/endpoint/data/v1/action/insertOne"

# Define API key
api_key="vHnQt5Jbff16nw3IZv40qFGZs1VMkICb3jVFLClOCxaG3WEQcRk4bXSnpvVtx4DH"

# Send data to MongoDB Data API using curl and handle errors
response=$(curl -sS -X POST -H "Content-Type: application/json" -H "api-key: $api_key" -d "$payload" "$api_endpoint")

if [ $? -eq 0 ]; then
  log_message "Data sent successfully. Response: $response"
else
  log_error "Failed to send data to MongoDB API. Response: $response"
fi