# Configuration variables
ARTICLE="testing2"
PLATFORM="gcp"

# Scenarios: Number of projects and VUs per project
scenario_number_of_project=("1" "3" "5")

scenario_number_of_vus=("1" "100" "500" "1000" "2000")

# Variable
EMAIL="riandyhsn@gmail.com"
PASSWORD="babiguling123"
K6_RUN_URL="http://localhost:3001/run"
K6_TEST_URL_1="http://localhost:3002/test1"
K6_TEST_URL_2="http://localhost:3003/test2"
K6_TEST_URL_3="http://localhost:3004/test3"
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
    local response=$(curl -s https://infra.antrein14.cloud)
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
  local max_retries=1000
  local retry_count=0
  local success=false

  while [ $retry_count -lt $max_retries ]; do
    local response=$(curl -s -w "\nHTTP_STATUS_CODE:%{http_code}" https://infra.antrein14.cloud)
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

# Fetch infra_mode and be_mode
infra_be_modes=($(fetch_infra_mode_and_be_mode))
infra_mode=${infra_be_modes[0]}
be_mode=${infra_be_modes[1]}
BASE_URL="https://api.antrein14.cloud/${be_mode}/dashboard"

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

  RESPONSE=$(curl -s -w "\nHTTP_STATUS_CODE:%{http_code}" -X POST "$BASE_URL/auth/login" -H "Content-Type: application/json" -d "$LOGIN_DATA")
  HTTP_STATUS=$(echo "$RESPONSE" | grep 'HTTP_STATUS_CODE' | awk -F: '{print $2}')
  RESPONSE_BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS_CODE/d')

  if [ "$HTTP_STATUS" -eq 200 ]; then
    token=$(echo "$RESPONSE_BODY" | jq -r '.data.token')
    if [ "$token" = "null" ] || [ -z "$token" ]; then
      echo "Login failed: token is null or empty. Response: $RESPONSE_BODY"
      exit 1
    fi
    echo "Login successful. Token: $token"
  else
    echo "Login failed with HTTP status $HTTP_STATUS. Response: $RESPONSE_BODY"
    exit 1
  fi
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
  check_server_health

  CREATE_PROJECT_RESPONSE=$(curl -s -w "\nHTTP_STATUS_CODE:%{http_code}" -X POST "$BASE_URL/project/" -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d "$CREATE_PROJECT_DATA")
  HTTP_STATUS=$(echo "$CREATE_PROJECT_RESPONSE" | grep 'HTTP_STATUS_CODE' | awk -F: '{print $2}')
  RESPONSE_BODY=$(echo "$CREATE_PROJECT_RESPONSE" | sed '/HTTP_STATUS_CODE/d')
  
  if [[ "$HTTP_STATUS" =~ ^2 ]]; then
    echo "Project $project_id created successfully."
  else
    echo "be-run: Failed to create project $project_id. Exiting."
    echo $RESPONSE_BODY
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

  check_server_health
  
  CONFIG_PROJECT_RESPONSE=$(curl -s -w "\nHTTP_STATUS_CODE:%{http_code}" -X PUT "$BASE_URL/project/config" -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d "$CONFIG_PROJECT_DATA")
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
  local timestamp=$3
  local project_urls=()
  for ((i=1; i<=num_projects; i++)); do
    project_id="${ARTICLE}${NODES}${CPU}${MEMORY}${s}${timestamp}${i}"
    project_url="https://${project_id}.antrein14.cloud/"
    project_urls+=("$project_url")
  done
  echo "${project_urls[@]}"
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
  RESPONSE=$(curl -s -w "\nHTTP_STATUS_CODE:%{http_code}" -X DELETE "https://api.antrein14.cloud/${be_mode}/dashboard/project/clear" -H "Authorization: Bearer $token" -H "Content-Type: application/json")
  HTTP_STATUS=$(echo "$RESPONSE" | grep 'HTTP_STATUS_CODE' | awk -F: '{print $2}')
  RESPONSE_BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS_CODE/d')

  if [ "$HTTP_STATUS" -eq 200 ]; then
    echo -e "\nAll projects cleared."
  else
    echo "be-run.sh: Error clearing projects. HTTP status: $HTTP_STATUS. Response: $RESPONSE_BODY"
    exit 1
  fi
}

# Function to send run request to the local server
send_run_request() {
  echo "Creating run request"
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
    --arg token "$token" \
    '{
      vus_per_endpoint: $vus_per_endpoint,
      endpoints: $endpoints,
      platform: $platform,
      nodes: $nodes,
      cpu: $cpu,
      memory: $memory,
      infra_mode: $infra_mode,
      be_mode: $be_mode,
      token: $token
    }')

  echo "request payload"
  echo $json_payload

  response=$(curl -s -w "\nHTTP_STATUS_CODE:%{http_code}" -X POST "$K6_RUN_URL" -H "Content-Type: application/json" -d "$json_payload")
  http_code=$(echo "$response" | grep 'HTTP_STATUS_CODE' | awk -F: '{print $2}')
  response_body=$(echo "$response" | sed '/HTTP_STATUS_CODE/d')
  
  if [ "$http_code" -eq 200 ]; then
    echo "Run completed."
  else
    echo "Error: Received HTTP status code $http_code"
    echo "Endpoint: $K6_RUN_URL"
    echo "Payload: $json_payload"
    echo "Response: $response_body"
  fi
  echo ""
}

# Function to send test request to the local server
send_test_request() {
  local test_url=$1
  local vus_per_endpoint=$2
  shift 2
  local project_urls=("$@")

  echo "Creating request for $test_url"

  local json_payload=$(jq -n \
    --argjson endpoints "$(printf '%s\n' "${project_urls[@]}" | jq -R . | jq -s .)" \
    --arg vus_per_endpoint "$vus_per_endpoint" \
    --arg platform "$PLATFORM" \
    --arg nodes "$NODES" \
    --arg cpu "$CPU" \
    --arg memory "$MEMORY" \
    --arg infra_mode "$infra_mode" \
    --arg be_mode "$be_mode" \
    --arg token "$token" \
    '{
      vus_per_endpoint: $vus_per_endpoint,
      endpoints: $endpoints,
      platform: $platform,
      nodes: $nodes,
      cpu: $cpu,
      memory: $memory,
      infra_mode: $infra_mode,
      be_mode: $be_mode,
      token: $token
    }')

  echo "request payload"
  echo $json_payload

  response=$(curl -s -w "\nHTTP_STATUS_CODE:%{http_code}" -X POST "$test_url" -H "Content-Type: application/json" -d "$json_payload")
  http_code=$(echo "$response" | grep 'HTTP_STATUS_CODE' | awk -F: '{print $2}')
  response_body=$(echo "$response" | sed '/HTTP_STATUS_CODE/d')
  
  if [ "$http_code" -eq 200 ]; then
    echo "be-run.sh: Test completed and data uploaded to Google Sheets."
  else
    echo "Error: Received HTTP status code $http_code"
    echo "Endpoint: $test_url"
    echo "Payload: $json_payload"
    echo "Response: $response_body"
  fi
  echo ""
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
  timestamp=$(date +%H%M%S)
  for ((i=1; i<=project_count; i++)); do
    project_id="${ARTICLE}${NODES}${CPU}${MEMORY}${project_count}${timestamp}${i}"
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
  project_urls=($(gather_project_urls $project_count $project_count $timestamp))
  for vus_count in "${scenario_number_of_vus[@]}"; do
    check_server_health
    
    # Start run and test requests in parallel
    send_run_request "$vus_count" "${project_urls[@]}" &
    sleep 5
    
    send_test_request "$K6_TEST_URL_1" "$project_count" "${project_urls[@]}" &
    send_test_request "$K6_TEST_URL_2" "$project_count" "${project_urls[@]}" &
    send_test_request "$K6_TEST_URL_3" "$project_count" "${project_urls[@]}" &
    
    wait -n

    echo "Pausing 10 seconds between testing scenarios"
    sleep 10
  done

  # Pause for 60 seconds to ramp down
  echo "Pausing for 60 seconds to ramp down after testing all scenarios"
  for ((i=0; i<60; i++)); do
    echo -ne "Ramping down, please wait... $((60-i))\r"
    sleep 1
  done
  echo -ne '\n'
done

echo " "
echo "TEST FINISHED"
echo " "