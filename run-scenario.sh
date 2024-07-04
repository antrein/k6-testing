#!/bin/bash

# Configuration variables
ARTICLE="test4"
PLATFORM="gcp"

# Scenarios: Number of projects and VUs per project
scenario_number_of_project=(
  "1"
  "3"
  "5"
)

scenario_number_of_vus=(
  "1"
  "100"
  "500"
  "1000"
  "5000"
)

# Variable
EMAIL="riandyhsn@gmail.com"
PASSWORD="babiguling123"
BASE_URL="https://api.antrein.com/bc/dashboard"
K6_TEST_URL="http://localhost:3001/test"
HTML_HOST="demo-ticketing.site"
THRESHOLD=2
SESSION_TIME=1
MAX_USERS_IN_QUEUE=10
QUEUE_START="2024-07-03T12:34:56"
QUEUE_END="2024-07-03T23:59:59"

# Function to log in and retrieve the token
login() {
  echo "Logging in..."
  LOGIN_DATA=$(cat <<EOF
{
  "email": "$EMAIL",
  "password": "$PASSWORD"
}
EOF
)

  RESPONSE=$(curl -s -X POST "$BASE_URL/auth/login" -H "Content-Type: application/json" -d "$LOGIN_DATA")
  TOKEN=$(echo $RESPONSE | jq -r '.data.token')

  if [ "$TOKEN" = "null" ]; then
    echo "Login failed. Exiting."
    exit 1
  fi

  echo "Login successful. Token: $TOKEN"
}

# Function to create and configure a project
create_and_configure_project() {
  local project_id=$1

  CREATE_PROJECT_DATA=$(cat <<EOF
{
  "id": "$project_id",
  "name": "$project_id"
}
EOF
  )

  CREATE_PROJECT_RESPONSE=$(curl -s -w "\nHTTP_STATUS_CODE:%{http_code}" -X POST "$BASE_URL/project" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$CREATE_PROJECT_DATA")
  HTTP_STATUS=$(echo "$CREATE_PROJECT_RESPONSE" | grep 'HTTP_STATUS_CODE' | awk -F: '{print $2}')
  RESPONSE_BODY=$(echo "$CREATE_PROJECT_RESPONSE" | sed '/HTTP_STATUS_CODE/d')
  
  if [[ "$HTTP_STATUS" =~ ^2 ]]; then
    echo "Project $project_id created successfully."
  else
    echo "Failed to create project $project_id. Exiting."
    exit 1
  fi

  CONFIG_PROJECT_DATA=$(cat <<EOF
{
  "project_id": "$project_id",
  "threshold": $THRESHOLD,
  "session_time": $SESSION_TIME,
  "host": "$HTML_HOST",
  "base_url": "/",
  "max_users_in_queue": $MAX_USERS_IN_QUEUE,
  "queue_start": "$QUEUE_START",
  "queue_end": "$QUEUE_END"
}
EOF
  )

  CONFIG_PROJECT_RESPONSE=$(curl -s -w "\nHTTP_STATUS_CODE:%{http_code}" -X PUT "$BASE_URL/project/config" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$CONFIG_PROJECT_DATA")
  HTTP_STATUS=$(echo "$CONFIG_PROJECT_RESPONSE" | grep 'HTTP_STATUS_CODE' | awk -F: '{print $2}')
  RESPONSE_BODY=$(echo "$CONFIG_PROJECT_RESPONSE" | sed '/HTTP_STATUS_CODE/d')

  if [[ "$HTTP_STATUS" =~ ^2 ]]; then
    echo "Project $project_id configured successfully."
  else
    echo "Failed to configure project $project_id. Exiting."
    exit 1
  fi

  echo "Project $project_id created and configured."
}

# Function to gather project URLs
gather_project_urls() {
  local num_projects=$1
  local s=$2
  local project_urls=()
  for ((i=1; i<=num_projects; i++)); do
    project_id="${ARTICLE}${s}${i}"
    project_url="https://${project_id}.antrein.cloud/"
    project_urls+=("$project_url")
  done
  echo "${project_urls[@]}"
}

# Function to fetch infra_mode and be_mode
fetch_infra_mode_and_be_mode() {
  local response=$(curl -s https://infra.antrein.com)
  local infra_mode=$(echo $response | jq -r '.infra_mode')
  local be_mode=$(echo $response | jq -r '.be_mode')
  echo $infra_mode $be_mode
}

# Function to send test request to the local server
send_test_request() {
  echo "Creating request"
  local vus_per_endpoint=$1
  shift
  local project_urls=("$@")
  local infra_be_modes=($(fetch_infra_mode_and_be_mode))
  local infra_mode=${infra_be_modes[0]}
  local be_mode=${infra_be_modes[1]}

  local json_payload=$(jq -n \
    --argjson endpoints "$(printf '%s\n' "${project_urls[@]}" | jq -R . | jq -s .)" \
    --arg vus_per_endpoint "$vus_per_endpoint" \
    --arg platform "$PLATFORM" \
    --arg nodes "$NODES" \
    --arg cpu "$CPU" \
    --arg memory "$MEMORY" \
    --arg infra_mode "$infra_mode" \
    --arg be_mode "$be_mode" \
    '{
      vus_per_endpoint: $vus_per_endpoint,
      endpoints: $endpoints,
      platform: $platform,
      nodes: $nodes,
      cpu: $cpu,
      memory: $memory,
      infra_mode: $infra_mode,
      be_mode: $be_mode
    }')

  echo "request payload"
  echo $json_payload

  response=$(curl -s -w "\nHTTP_STATUS_CODE:%{http_code}" -X POST "$K6_TEST_URL" -H "Content-Type: application/json" -d "$json_payload")
  http_code=$(echo "$response" | grep 'HTTP_STATUS_CODE' | awk -F: '{print $2}')
  
  if [ "$http_code" -eq 200 ]; then
    echo "Test completed and data uploaded to Google Sheets."
  else
    echo "Error: Received HTTP status code $http_code"
  fi
  echo ""
}

# Function to fetch cluster details for GCP
fetch_gcp_cluster_details() {
  local cluster_details=($(./get-cluster/gcp.sh))
  NODES="${cluster_details[0]}"
  CPU="${cluster_details[1]}"
  MEMORY="${cluster_details[2]}"
}

# Function to clear projects
clear_projects() {
  echo "Clearing all projects..."
  curl -X DELETE "https://api.antrein.com/bc/dashboard/project/clear" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json"
  echo -e "\nAll projects cleared."
}

# Main script
login

# Fetch cluster details if platform is GCP
if [ "$PLATFORM" == "gcp" ]; then
  fetch_gcp_cluster_details
elif [ "$PLATFORM" == "aws" ]; then
  # Placeholder for fetching AWS cluster details
  echo "Fetching AWS cluster details... (Not implemented yet)"
elif [ "$PLATFORM" == "azure" ]; then
  # Placeholder for fetching Azure cluster details
  echo "Fetching Azure cluster details... (Not implemented yet)"
fi

# Run tests for each scenario
for project_count in "${scenario_number_of_project[@]}"; do
  clear_projects
  echo "Creating resources for $project_count projects"
  for ((i=1; i<=project_count; i++)); do
    project_id="${ARTICLE}${project_count}${i}"
    create_and_configure_project $project_id
  done

  # Pause for resources to provision
  echo "Pausing for 60 seconds to provision resources"
  for ((i=0; i<60; i++)); do
    echo -ne "Provisioning resources, please wait... $((60-i))\r"
    sleep 1
  done
  echo -ne '\n'

  echo "Run k6 testing for $project_count projects"
  project_urls=($(gather_project_urls $project_count $project_count))
  for vus_count in "${scenario_number_of_vus[@]}"; do
    send_test_request "$vus_count" "${project_urls[@]}"
    echo "Pausing 10 seconds between testing scenarios"
    sleep 10
  done
done
