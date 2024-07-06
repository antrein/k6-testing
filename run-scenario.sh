#!/bin/bash

# Configuration variables
ARTICLE="testing1"
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
  "2000"
)

# Stress testing VUs
stress_vus=(
  "18000"
  "20000"
  "22000"
  "24000"
  "28000"
  "32000"
  "35000"
  "40000"
)

# Variable
EMAIL="riandyhsn@gmail.com"
PASSWORD="babiguling123"
K6_TEST_URL="http://localhost:3001/test"
K6_TEST_STRESS_URL="http://localhost:3001/test-stress"
K6_PUSH_STRESS_URL="http://localhost:3001/push-test-stress"
HTML_HOST="demo-ticketing.site"
THRESHOLD=2
SESSION_TIME=1
MAX_USERS_IN_QUEUE=10
QUEUE_START="2024-07-03T12:34:56"
QUEUE_END="2024-07-03T23:59:59"

# Function to fetch infra_mode and be_mode
fetch_infra_mode_and_be_mode() {
  local max_retries=50
  local retry_count=0
  local success=false
  
  while [ $retry_count -lt $max_retries ]; do
    local response=$(curl -s https://infra.antrein6.cloud)
    if [ $? -eq 0 ]; then
      local infra_mode=$(echo $response | jq -r '.infra_mode')
      local be_mode=$(echo $response | jq -r '.be_mode')
      if [[ -n "$infra_mode" && -n "$be_mode" ]]; then
        echo $infra_mode $be_mode
        success=true
        break
      fi
    fi
    echo "Retry $((retry_count+1))/$max_retries: Failed to fetch infra_mode and be_mode. Retrying in 5 seconds..."
    retry_count=$((retry_count + 1))
    sleep 5
  done

  if [ "$success" = false ]; then
    echo "Failed to fetch infra_mode and be_mode after $max_retries attempts. Exiting."
    exit 1
  fi
}

# Function to check server health
check_server_health() {
  local max_retries=50
  local retry_count=0
  local success=false

  while [ $retry_count -lt $max_retries ]; do
    local response=$(curl -s -w "\nHTTP_STATUS_CODE:%{http_code}" https://infra.antrein6.cloud)
    local http_code=$(echo "$response" | grep 'HTTP_STATUS_CODE' | awk -F: '{print $2}')
    
    if [ "$http_code" -eq 200 ]; then
      echo "Server is healthy."
      success=true
      break
    else
      echo "Server health check failed with status code $http_code. Retrying in 5 seconds..."
      retry_count=$((retry_count + 1))
      sleep 5
    fi
  done

  if [ "$success" = false ]; then
    echo "Server health check failed after $max_retries attempts. Exiting."
    exit 1
  fi
}

check_stress_test_health() {
  local response=$(curl -s -w "\nHTTP_STATUS_CODE:%{http_code}" https://infra.antrein6.cloud)
  local http_code=$(echo "$response" | grep 'HTTP_STATUS_CODE' | awk -F: '{print $2}')
  
  if [ "$http_code" -eq 200 ]; then
    echo "Server is healthy."
    return 0
  else
    echo "Server health check failed with status code $http_code."
    return 1
  fi
}

# Fetch infra_mode and be_mode
infra_be_modes=($(fetch_infra_mode_and_be_mode))
infra_mode=${infra_be_modes[0]}
be_mode=${infra_be_modes[1]}
BASE_URL="https://api.antrein6.cloud/${be_mode}/dashboard"

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
    project_id="${ARTICLE}${NODES}${CPU}${MEMORY}${s}${i}"
    project_url="https://${project_id}.antrein6.cloud/"
    project_urls+=("$project_url")
  done
  echo "${project_urls[@]}"
}

# Function to send test request to the local server
send_test_request() {
  echo "Creating request"
  local vus_per_endpoint=$1
  shift
  local project_urls=("$@")

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
  curl -X DELETE "https://api.antrein6.cloud/${be_mode}/dashboard/project/clear" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json"
  echo -e "\nAll projects cleared."
}

# Function to send stress test request to the local server
send_stress_test_request() {
  echo "Creating stress test request"
  local vus_per_endpoint=$1
  shift
  local project_urls=("$@")

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

  response=$(curl -s -w "\nHTTP_STATUS_CODE:%{http_code}" -X POST "$K6_TEST_STRESS_URL" -H "Content-Type: application/json" -d "$json_payload")
  http_code=$(echo "$response" | grep 'HTTP_STATUS_CODE' | awk -F: '{print $2}')
  
  if [ "$http_code" -eq 200 ]; then
    echo "Stress test passed, continue to next scenario."
    return 0
  elif [ "$http_code" -eq 201 ]; then
    echo "Stress test failed and data uploaded to Google Sheets."
    return 1
  else
    echo "Error: Received HTTP status code $http_code"
    return 2
  fi
  echo ""
}

# Function to send data to /push-stress-test endpoint
send_push_stress_test() {
  local vus_per_endpoint=$1
  shift
  local project_urls=("$@")

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

  echo "Sending data to /push-stress-test"
  echo $json_payload

  response=$(curl -s -w "\nHTTP_STATUS_CODE:%{http_code}" -X POST "$K6_PUSH_STRESS_URL" -H "Content-Type: application/json" -d "$json_payload")
  http_code=$(echo "$response" | grep 'HTTP_STATUS_CODE' | awk -F: '{print $2}')
  
  if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
    echo "Data uploaded to Google Sheets."
    return 0
  else
    echo "Error: Received HTTP status code $http_code"
    return 1
  fi
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

# Run tests for each scenario and stress test for a single project
for project_count in "${scenario_number_of_project[@]}"; do
  # Check server health before starting the iteration
  check_server_health

  clear_projects
  echo "Creating resources for $project_count projects"
  for ((i=1; i<=project_count; i++)); do
    check_server_health
    project_id="${ARTICLE}${NODES}${CPU}${MEMORY}${project_count}${i}"
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
    check_server_health
    send_test_request "$vus_count" "${project_urls[@]}"
    echo "Pausing 10 seconds between testing scenarios"
    sleep 10
  done

  # Run stress testing only when the project count is 1
if [ "$project_count" -eq 1 ]; then
  echo "Run k6 stress testing for 1 project"
  for vus_count in "${stress_vus[@]}"; do
    check_server_health

    project_urls=($(gather_project_urls $project_count $project_count))
    send_stress_test_request "$vus_count" "${project_urls[@]}"
    case $? in
      0)
        # Passed
        echo "Stress test passed, continue to next scenario."
        if ! check_stress_test_health; then
          send_push_stress_test "$vus_count" "${project_urls[@]}"
          break
        fi
        ;;
      1)
        # Failed
        echo "Stress testing stopped due to failure."
        break
        ;;
      2)
        # Error
        echo "Error occurred, exiting."
        exit 1
        ;;
    esac
    echo "Pausing 10 seconds between stress testing scenarios"
    sleep 10
  done

  # Pause for 60 seconds to ramp down
  echo "Pausing for 60 seconds to ramp down after stress testing"
  for ((i=0; i<60; i++)); do
    echo -ne "Ramping down, please wait... $((60-i))\r"
    sleep 1
  done
  echo -ne '\n'
fi
done
echo " "
echo "TEST FINISHED"
echo " "