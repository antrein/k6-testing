#!/bin/bash

# Configuration variables
PROMETHEUS_URL="https://prometheus.antrein.com"
NAMESPACE="production"
STEP="5s" # Interval between data points

# Validate arguments
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <START_TIME> <END_TIME>"
  echo "Example: $0 2024-07-04T05:00:00Z 2024-07-04T05:05:00Z"
  exit 1
fi

START_TIME=$1
END_TIME=$2

# Prometheus query functions
query_prometheus() {
  local query=$1
  local start=$2
  local end=$3
  local step=$4
  curl -s -G --data-urlencode "query=$query" \
    --data-urlencode "start=$start" \
    --data-urlencode "end=$end" \
    --data-urlencode "step=$step" \
    "$PROMETHEUS_URL/api/v1/query_range"
}

# Fetch max CPU usage
cpu_usage_query="sum(rate(container_cpu_usage_seconds_total{namespace=\"$NAMESPACE\"}[1m]))"
cpu_response=$(query_prometheus "$cpu_usage_query" "$START_TIME" "$END_TIME" "$STEP")

max_cpu=$(echo $cpu_response | jq '[.data.result[].values[] | .[1] | tonumber] | max')

# Fetch max memory usage
memory_usage_query="sum(container_memory_working_set_bytes{namespace=\"$NAMESPACE\"})"
memory_response=$(query_prometheus "$memory_usage_query" "$START_TIME" "$END_TIME" "$STEP")

max_memory=$(echo $memory_response | jq '[.data.result[].values[] | .[1] | tonumber] | max / 1024 / 1024')

# Output results formatted to two decimal places
printf "Max CPU usage (cores): %.7f\n" "$max_cpu"
printf "Max memory usage (MB): %.5f\n" "$max_memory"
