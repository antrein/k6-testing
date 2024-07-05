#!/bin/bash

# Check if the number of projects is passed as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 <number_of_projects>"
  exit 1
fi

# Number of projects to create
NUM_PROJECTS=$1
ARTICLE="test5"

# Base URL
BASE_URL="https://api.antrein5.cloud/bc/dashboard"

# Credentials
EMAIL="riandyhsn@gmail.com"
PASSWORD="babiguling123"

# Step 1: Clear all projects
# echo "Clearing all projects..."
# curl -X DELETE "$BASE_URL/bc/dashboard/project/clear" -H "Content-Type: application/json"
# echo -e "\nAll projects cleared."

# Step 2: Login
echo "Logging in..."
LOGIN_DATA=$(cat <<EOF
{
  "email": "$EMAIL",
  "password": "$PASSWORD"
}
EOF
)

echo "Login Request Data: $LOGIN_DATA"
RESPONSE=$(curl -s -X POST "$BASE_URL/auth/login" -H "Content-Type: application/json" -d "$LOGIN_DATA")
echo "Response: $RESPONSE"
TOKEN=$(echo $RESPONSE | jq -r '.data.token')

if [ "$TOKEN" = "null" ]; then
  echo "Login failed. Exiting."
  exit 1
fi

echo "Login successful. Token: $TOKEN"
echo -e "\n"

# Step 3: Loop to create projects
for ((i=1; i<=NUM_PROJECTS; i++)); do
  PROJECT_ID="${ARTICLE}$i"

  CREATE_PROJECT_DATA=$(cat <<EOF
{
  "id": "$PROJECT_ID",
  "name": "$PROJECT_ID"
}
EOF
)

  echo "Creating project $PROJECT_ID..."
  echo "Create Project Request Data: $CREATE_PROJECT_DATA"
  CREATE_PROJECT_RESPONSE=$(curl -s -w "\nHTTP_STATUS_CODE:%{http_code}" -X POST "$BASE_URL/project" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$CREATE_PROJECT_DATA")
  HTTP_STATUS=$(echo "$CREATE_PROJECT_RESPONSE" | grep 'HTTP_STATUS_CODE' | awk -F: '{print $2}')
  RESPONSE_BODY=$(echo "$CREATE_PROJECT_RESPONSE" | sed '/HTTP_STATUS_CODE/d')
  
  echo "URL: $BASE_URL/project"
  echo "Request: $CREATE_PROJECT_DATA"
  echo "Response: $RESPONSE_BODY"
  echo "HTTP Status Code: $HTTP_STATUS"
  echo "-----------"

  if [[ "$HTTP_STATUS" =~ ^2 ]]; then
    echo "Project $PROJECT_ID created successfully."
  else
    echo "Failed to create project $PROJECT_ID. Exiting."
    exit 1
  fi

  CONFIG_PROJECT_DATA=$(cat <<EOF
{
  "project_id": "$PROJECT_ID",
  "threshold": 2,
  "session_time": 1,
  "host": "demo-ticketing.site",
  "base_url": "/",
  "max_users_in_queue": 10,
  "queue_start": "2024-07-03T12:34:56",
  "queue_end": "2024-07-03T23:59:59"
}
EOF
)

  echo -e "\nConfiguring project $PROJECT_ID..."
  echo "Config Project Request Data: $CONFIG_PROJECT_DATA"
  CONFIG_PROJECT_RESPONSE=$(curl -s -w "\nHTTP_STATUS_CODE:%{http_code}" -X PUT "$BASE_URL/project/config" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$CONFIG_PROJECT_DATA")
  HTTP_STATUS=$(echo "$CONFIG_PROJECT_RESPONSE" | grep 'HTTP_STATUS_CODE' | awk -F: '{print $2}')
  RESPONSE_BODY=$(echo "$CONFIG_PROJECT_RESPONSE" | sed '/HTTP_STATUS_CODE/d')

  echo "URL: $BASE_URL/project/config"
  echo "Request: $CONFIG_PROJECT_DATA"
  echo "Response: $RESPONSE_BODY"
  echo "HTTP Status Code: $HTTP_STATUS"
  echo "-----------"

  if [[ "$HTTP_STATUS" =~ ^2 ]]; then
    echo "Project $PROJECT_ID configured successfully."
  else
    echo "Failed to configure project $PROJECT_ID. Exiting."
    exit 1
  fi

  echo -e "\nProject $PROJECT_ID created and configured."
done

echo "All projects created and configured."
