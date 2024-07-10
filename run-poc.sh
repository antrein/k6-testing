#!/bin/bash

# Define the URLs and VUs
declare -a urls=("https://demo-ticketing.site/" "https://demo1.antrein14.cloud/")
declare -a vus=("10"  "100" "300" "500" "1000" "3000" "5000" "10000")

# Loop through each URL and VU combination and make the POST request
for vu in "${vus[@]}"
do
  for url in "${urls[@]}"
  do
    echo "Testing URL: $url with VUs: $vu"
    response=$(curl -s -w "%{http_code}" -X POST http://localhost:3001/test -H "Content-Type: application/json" -d "{\"vus\": $vu, \"endpoint\": \"$url\"}")
    http_code=$(echo "$response" | tail -n1)
    if [ "$http_code" -eq 200 ]; then
      echo "Test completed and data uploaded to Google Sheets."
    else
      echo "Error: Received HTTP status code $http_code"
    fi
    echo ""
  done
done